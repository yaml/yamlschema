JSON Schema Roundtrip
=====================

`yamlschema` is designed to interoperate with JSON Schema in both directions:

```text
contact.schema.json
  -> contact.ysc.yaml
  -> contact.ysc.json
  -> contact.schema.json
```

The roundtrip goal is semantic equivalence, not byte-for-byte equality.
JSON Schema has many equivalent ways to express the same constraint, and
yamlschema has both succinct and explicit forms.
A roundtripped JSON Schema may be normalized, reordered, or expanded, while
still validating the same data.


## Roundtrip Model

There are three useful representations:

```text
contact.schema.json
  -> contact.ysc.yaml
  -> contact.ysc.json
  -> contact.schema.json
```

The `.ysc.yaml` succinct form is optimized for humans:

```yaml
name: +Str
email?: /^\S+@\S+$/
tags[!+]: +Str
```

The `.ysc.json` explicit form is the canonical internal shape:

```json
{
  "name": {"-need": "+Str"},
  "email": {"-type": "+Str", "-like": "/^\\S+@\\S+$/"},
  "tags": {
    "-need": "+Str",
    "-list": true,
    "-uniq": true,
    "-size": [1, "*"]
  }
}
```

The `.schema.json` JSON Schema output is generated from the explicit form:

```json
{
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "email": {"type": "string", "pattern": "^\\S+@\\S+$"},
    "tags": {
      "type": "array",
      "items": {"type": "string"},
      "uniqueItems": true,
      "minItems": 1
    }
  },
  "required": ["name", "tags"]
}
```

Use `.schema.json` for JSON Schema files, `.ysc.yaml` for human-maintained
yamlschema DSL files, and `.ysc.json` for compiled yamlschema files.


## Current Direction

The current repo implements the first direction with `bin/ysc`:

```text
contact.schema.json -> contact.ysc.yaml
```

The reverse direction is part of the design:

```text
contact.ysc.yaml -> contact.ysc.json -> contact.schema.json
```

That reverse compiler should target the explicit form, because succinct syntax
is sugar.
Once succinct yamlschema has been expanded, JSON Schema generation is mostly a
directive-to-keyword mapping.


## Required and Optional Properties

JSON Schema marks required keys in a sibling `required` array:

```json
{
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "email": {"type": "string"}
  },
  "required": ["name"]
}
```

yamlschema marks optional keys locally:

```yaml
name: +Str
email?: +Str
```

Roundtrip back to JSON Schema:

```json
{
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "email": {"type": "string"}
  },
  "required": ["name"]
}
```

If no keys are required, the `required` array can be omitted.


## Built-in Types

| JSON Schema | yamlschema |
| --- | --- |
| `{"type": "string"}` | `+Str` |
| `{"type": "integer"}` | `+Int` |
| `{"type": "number"}` | `+Float` |
| `{"type": "boolean"}` | `+Bool` |
| `{"type": "null"}` | `+Null` |
| `{"type": "object"}` | `+Map` or a mapping shape |
| `{"type": "array"}` | `-list: true` or a list key suffix |

Example:

```json
{
  "properties": {
    "s": {"type": "string"},
    "i": {"type": "integer"},
    "n": {"type": "number"},
    "b": {"type": "boolean"}
  },
  "required": ["s", "i", "n", "b"]
}
```

converts to:

```yaml
s: +Str
i: +Int
n: +Float
b: +Bool
```


## Regex Patterns

JSON Schema:

```json
{
  "properties": {
    "email": {"type": "string", "pattern": "^\\S+@\\S+$"},
    "zip": {"pattern": "^\\d{5}$"}
  },
  "required": ["email", "zip"]
}
```

yamlschema:

```yaml
email: /^\S+@\S+$/
zip: /^\d{5}$/
```

Roundtrip notes:

- JSON Schema regexes are strings.
- yamlschema regexes are delimited with `/`.
- `/` characters inside the pattern must be escaped in yamlschema.
- A yamlschema regex implies string validation.


## Enums

Simple token enums roundtrip through pipe syntax:

```json
{
  "properties": {
    "role": {"enum": ["admin", "user", "guest"]}
  },
  "required": ["role"]
}
```

```yaml
role: admin|user|guest
```

Values that are not safe pipe tokens use explicit `-enum`:

```json
{
  "properties": {
    "label": {"enum": ["has space", "ok"]}
  },
  "required": ["label"]
}
```

```yaml
label:
  -enum:
  - has space
  - ok
```

Both forms roundtrip back to:

```json
{"enum": ["has space", "ok"]}
```

when used as a property schema.


## Constants

JSON Schema:

```json
{
  "properties": {
    "version": {"const": "v1"},
    "kind": {"const": "User"}
  },
  "required": ["version", "kind"]
}
```

yamlschema:

```yaml
version: v1
kind: User
```

Roundtrip back to JSON Schema should preserve this as `const`, not as an enum
with one value:

```json
{
  "properties": {
    "version": {"const": "v1"},
    "kind": {"const": "User"}
  },
  "required": ["version", "kind"]
}
```


## Ranges and Sizes

Numeric ranges:

```json
{
  "properties": {
    "port": {"type": "integer", "minimum": 1, "maximum": 65535},
    "age": {"type": "integer", "minimum": 0},
    "ratio": {"type": "number", "minimum": 0, "maximum": 1}
  },
  "required": ["port", "age", "ratio"]
}
```

```yaml
port: 1-65535
age: 0-*
ratio: 0-1
```

String lengths use `-size`:

```json
{
  "properties": {
    "bio": {"type": "string", "minLength": 1, "maxLength": 500},
    "code": {"type": "string", "minLength": 3}
  },
  "required": ["bio", "code"]
}
```

```yaml
bio:
  -type: +Str
  -size:
  - 1
  - 500
code:
  -type: +Str
  -size:
  - 3
  - '*'
```

Roundtrip rule:

- `-size` on `+Int` or `+Float` maps to `minimum` and `maximum`.
- `-size` on `+Str` maps to `minLength` and `maxLength`.
- `-size` on lists maps to `minItems` and `maxItems`.
- `-size` on maps maps to `minProperties` and `maxProperties`.
- `*` means the upper bound is absent.


## Arrays

Homogeneous arrays use key suffixes when possible:

```json
{
  "properties": {
    "tags": {"type": "array", "items": {"type": "string"}},
    "names": {
      "type": "array",
      "items": {"type": "string"},
      "minItems": 1
    },
    "triple": {
      "type": "array",
      "items": {"type": "integer"},
      "minItems": 3,
      "maxItems": 3
    },
    "subset": {
      "type": "array",
      "items": {"type": "string"},
      "minItems": 1,
      "maxItems": 3
    }
  },
  "required": ["tags", "names", "triple", "subset"]
}
```

```yaml
tags[]: +Str
names[+]: +Str
triple[3]: +Int
subset[1-3]: +Str
```

Unique arrays add `!`:

```json
{
  "type": "array",
  "items": {"type": "string"},
  "uniqueItems": true,
  "minItems": 1
}
```

```yaml
names[!+]: +Str
```

Roundtrip mapping:

| yamlschema | JSON Schema |
| --- | --- |
| `key[]: +Str` | `type: array`, `items: {type: string}` |
| `key[+]: +Str` | plus `minItems: 1` |
| `key[3]: +Int` | plus `minItems: 3`, `maxItems: 3` |
| `key[1-3]: +Str` | plus `minItems: 1`, `maxItems: 3` |
| `key[!]: +Str` | plus `uniqueItems: true` |
| `key[!+]: +Str` | plus `uniqueItems: true`, `minItems: 1` |


## Defaults

JSON Schema:

```json
{
  "properties": {
    "port": {"type": "integer", "default": 8080},
    "host": {"type": "string", "default": "localhost"}
  },
  "required": ["port", "host"]
}
```

yamlschema:

```yaml
port:
  -type: +Int
  -init: 8080
host:
  -type: +Str
  -init: localhost
```

Roundtrip rule: `-init` maps to JSON Schema `default`.


## Definitions and References

JSON Schema definitions become top-level symbols:

```json
{
  "$defs": {
    "port": {"type": "integer", "minimum": 1, "maximum": 65535},
    "email": {"type": "string", "pattern": "^\\S+@\\S+$"}
  },
  "properties": {
    "host": {"type": "string"},
    "port": {"$ref": "#/$defs/port"},
    "admin": {"$ref": "#/$defs/email"}
  },
  "required": ["host", "port"]
}
```

```yaml
+port: 1-65535
+email: /^\S+@\S+$/

host: +Str
port: +port
admin?: +email
```

Roundtrip back to JSON Schema:

```json
{
  "$defs": {
    "port": {"type": "integer", "minimum": 1, "maximum": 65535},
    "email": {"type": "string", "pattern": "^\\S+@\\S+$"}
  },
  "type": "object",
  "properties": {
    "host": {"type": "string"},
    "port": {"$ref": "#/$defs/port"},
    "admin": {"$ref": "#/$defs/email"}
  },
  "required": ["host", "port"]
}
```

Roundtrip notes:

- `$defs` and older `definitions` both import as `+name`.
- A local reference such as `#/$defs/email` imports as `+email`.
- Exporting back to JSON Schema should prefer `$defs`.
- Namespaced yamlschema symbols can map to external `$ref` URIs.


## Nested Objects

Nested JSON Schema objects become nested yamlschema mappings:

```json
{
  "type": "object",
  "properties": {
    "address": {
      "type": "object",
      "properties": {
        "street": {"type": "string"},
        "city": {"type": "string"},
        "country": {"type": "string"}
      },
      "required": ["street", "city"]
    }
  },
  "required": ["address"]
}
```

```yaml
address:
  street: +Str
  city: +Str
  country?: +Str
```

Roundtrip back to JSON Schema restores each object level with its own
`properties` and `required` array.


## Unsupported or Open JSON Schema Features

Some JSON Schema features need more yamlschema design before they can roundtrip
cleanly.

The current converter emits TODO comments for these when they are encountered:

```yaml
auth:
  # TODO: oneOf
```

Open mappings include:

| JSON Schema | Possible yamlschema direction |
| --- | --- |
| `allOf` | Type inheritance or composition |
| `anyOf` | Union constraint |
| `oneOf` | `-pick` |
| `not` | Negative constraint, still undecided |
| `if` / `then` / `else` | `-when` |
| `dependentRequired` | `-with` |
| `dependentSchemas` | Extended `-with` or conditional schema |
| `patternProperties` | Regex keys |
| `propertyNames` | Key constraints |
| `prefixItems` | Positional list schemas |
| `contains` | List membership constraints |
| `unevaluatedItems` | Strict list mode |
| `unevaluatedProperties` | Strict map mode |
| `exclusiveMinimum` / `exclusiveMaximum` | Open-bound range syntax |
| `format` | Semantic format annotations |

Likely out of scope or JSON Schema-specific:

- Dynamic references.
- Anchors.
- Vocabularies.
- Boolean schemas.
- Content/media validation.


## Information That May Not Roundtrip

Semantic roundtrip does not preserve every textual detail:

- JSON object key order may change.
- Whitespace and comments in JSON Schema are not preserved.
- Equivalent JSON Schema spellings may normalize to one spelling.
- `definitions` should export back as `$defs`.
- Succinct yamlschema may expand to explicit yamlschema before JSON generation.
- A pipe enum and an explicit `-enum` with the same values are equivalent.
- Unbounded `*` in yamlschema maps to an omitted JSON Schema bound.

Lossless source-preserving roundtrip would require storing source metadata in
addition to the schema semantics.


## Implementation Checklist

For full bidirectional roundtrip support:

1. Parse JSON Schema into explicit yamlschema.
2. Render explicit yamlschema as succinct syntax where safe.
3. Parse succinct yamlschema back to explicit yamlschema.
4. Generate JSON Schema from explicit yamlschema.
5. Normalize both JSON Schema documents.
6. Compare validation behavior, not raw source text.

The existing `bin/ysc` covers step 1 for the direct mappings listed above
and does some of step 2 by emitting succinct forms where possible.
