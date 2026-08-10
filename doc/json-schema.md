JSON Schema Roundtrip
=====================

`yamlschema` is designed to interoperate with JSON Schema in both directions:

```text
contact.schema.json
  -> contact.ysd.yaml
  -> contact.ysc.yaml or contact.ysc.json
  -> contact.schema.json
```

The roundtrip goal is semantic equivalence, not byte-for-byte equality.
JSON Schema has many equivalent ways to express the same constraint, and
yamlschema has both succinct and explicit forms.
A roundtripped JSON Schema may be normalized, reordered, or expanded, while
still validating the same data.


## Roundtrip Model

There are three useful semantic representations. Expanded yamlschema has YAML
and JSON serializations:

```text
contact.schema.json
  -> contact.ysd.yaml
  -> contact.ysc.yaml or contact.ysc.json
  -> contact.schema.json
```

The `.ysd.yaml` succinct form is optimized for humans:

```yaml
name: +Str
email?: +Str =~"\S+@\S+"
tags[!+]: +Str
```

The `.ysc.json` explicit form is one serialization of the canonical internal
shape:

```json
{
  "name": {".base": "+Str"},
  "email": {".base": "+Str", ".match": "\\S+@\\S+"},
  "tags": {
    ".base": "+Str",
    ".list": true,
    ".uniq": true,
    ".size": [1]
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

Use `.schema.json` for JSON Schema files and `.ysd.yaml` for human-maintained
yamlschema DSL files. Use `.ysc.yaml` or `.ysc.json` for the same non-human,
fully expanded yamlschema model.


## Conversion Directions

`bin/ysc` implements all four direct conversion targets:

```text
contact.schema.json -> contact.ysd.yaml
contact.ysd.yaml -> contact.ysc.yaml
contact.ysd.yaml -> contact.ysc.json
contact.ysd.yaml -> contact.schema.json
```

The explicit form is the shared expansion boundary:

```text
contact.ysd.yaml -> contact.ysc.yaml or contact.ysc.json
contact.ysd.yaml -> contact.schema.json
```

The compiler targets the explicit form because succinct syntax is sugar.
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
| `{"type": "object"}` | `+Map[+Any]` or a mapping shape |
| `{"type": "array"}` | `.list: true` or a list key suffix |

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
email: +Str =~"\S+@\S+"
zip: +Str =~"\d{5}"
```

Roundtrip notes:

- JSON Schema regexes are strings.
- `.match` is a whole-string match; `^` and `$` are implied and restored when
  exporting JSON Schema.
- `.find` is an unanchored search and exports its pattern unchanged.
- `/pattern/` is shorthand for `find:"pattern"` only when the body contains
  neither whitespace nor `/`.
- `=~"..."`, its accepted `match:"..."` alias, and `find:"..."` cannot contain
  `"`; use an explicit `.match` or `.find` property when needed. Generated
  yamlschema uses `=~"..."` for `.match`.
- In any tight double-quoted body, `:\ ` represents colon-space and ` \#`
  represents space-hash. Other backslash sequences remain literal.
- Both regex properties imply string validation.


## Enums

Simple token enums roundtrip through a base-qualified compact list:

```json
{
  "properties": {
    "role": {"enum": ["admin", "user", "guest"]}
  },
  "required": ["role"]
}
```

```yaml
role: +Str [admin,user,guest]
```

An enum default is marked on its member:

```yaml
logLevel: +Str [debug,=info,warning,error,fatal]
```

This expands to `.enum: [debug, info, warning, error, fatal]` plus
`.init: info`.

Compact members may contain whitespace; surrounding whitespace is trimmed and
interior whitespace is preserved. Thus `[foo,bar,foo bar]` and
`[ foo, bar, foo bar ]` are equivalent. Quoted members and punctuation other
than `.`, `-`, `_`, and `+` use explicit `.enum`:

```json
{
  "properties": {
    "symbol": {"enum": ["ok", "bad/value"]}
  },
  "required": ["label"]
}
```

```yaml
symbol:
  .base: +Str
  .enum:
  - ok
  - bad/value
```

Both forms roundtrip back to:

```json
{"enum": ["ok", "bad/value"]}
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
version: +Str ==v1
kind: +Str ==User
```

`==value` maps to `const`; `=="foo bar"` is the quoted form and
`const:value` is the labeled alternative. A following `=value` independently
adds JSON Schema `default`:

```yaml
fixed: +Str ==User =User
```

```json
{"const": "User", "default": "User"}
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
port: 1..65535
age: 0..
ratio: 0..1
```

String lengths use `.size`:

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
  .base: +Str
  .size:
  - 1
  - 500
code:
  .base: +Str
  .size:
  - 3
  - '*'
```

Roundtrip rule:

- `.range` on `+Int` or `+Float` maps its optional bounds to `minimum` and
  `maximum`.
- `.size` on `+Str` maps to `minLength` and `maxLength`.
- `.size` on lists maps to `minItems` and `maxItems`.
- `.size` on maps maps to `minProperties` and `maxProperties`.
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
names[1+]: +Str
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
| `key[1+]: +Str` | plus `minItems: 1` |
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
  .base: +Int
  .init: 8080
host:
  .base: +Str
  .init: localhost
```

Roundtrip rule: `.init` maps to JSON Schema `default`.


## Annotations

JSON Schema Draft 2020-12 is the only supported JSON Schema dialect for now.
The `$schema` keyword is implied by `.schema.json` output and is not encoded in
yamlschema.

Other JSON Schema metadata roundtrips through explicit yamlschema directives.
These fields do not affect validation, but keeping them preserves useful schema
metadata.

| JSON Schema | yamlschema |
| --- | --- |
| `$id` | `.json.$id` |
| `title` | `.title` |
| `description` | Trailing `"description"` or `.desc` |


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
+port: 1..65535
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


## Additional Properties

The reserved `+Str` key describes otherwise-unmatched string keys.
Its value is any yamlschema value schema:

```yaml
labels:
  +Str: +Str
config:
  enabled?: +Bool
  +Str: +Any
```

Explicit JSON Schema values import as follows:

| JSON Schema | yamlschema |
| --- | --- |
| `additionalProperties: true` | `+Map[+Any]` |
| `additionalProperties: {"type":"string"}` | `+Map[+Str]` |
| `additionalProperties: {"$ref":"..."}` | `+Map[+name]` |
| constrained `additionalProperties` | `+Str: schema` |
| `additionalProperties: false` | No wildcard |

On a shaped mapping, omitted `additionalProperties` imports without a
wildcard. This intentionally adopts yamlschema's stricter closed default for
shapes. A pure object with no declared properties remains open and imports as
`+Map[+Any]`.
On export, shaped mappings without `+Str` receive
`additionalProperties: false`.
Bare `+Map` is invalid; pure open objects use `+Map[+Any]`.

When named properties coexist with `additionalProperties`, the importer emits
an explicit wildcard after the named properties:

```yaml
labels:
  fixed?: +Str
  +Str: +Str
```

`+Map[+Type]` accepts one built-in, user-defined, or namespaced reference.
It is shorthand for the future `+Map[+Str,+Type]` form. Two-reference maps are
reserved for YAML key schemas but are not implemented. More complex value
constraints continue to use explicit `+Str` syntax.


## Schema Combinators

JSON Schema combinators round-trip through explicit directives:

| JSON Schema | yamlschema |
| --- | --- |
| `oneOf` | `.oneof` or `+One[...]` |
| `anyOf` | `.anyof` or `+Any[...]` |
| `allOf` | `.allof` or `+All[...]` |
| `not` | `.not` or `+Not[...]` |

The compact forms contain type references only. `One`, `Any`, and `All`
require at least two references. `Not` requires at least one; multiple
references mean `not(anyOf(...))`.


## Unsupported or Open JSON Schema Features

The converter emits TODO comments for features that still need design:

```yaml
auth:
  # TODO: if
```

Open mappings include:

| JSON Schema | Possible yamlschema direction |
| --- | --- |
| `if` / `then` / `else` | `.when` |
| `dependentRequired` | `.with` |
| `dependentSchemas` | Extended `.with` or conditional schema |
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
- A compact enum and an explicit `.enum` with the same values are equivalent.
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

The existing `bin/ysc` covers step 1 for the direct mappings listed above.
It does some of step 2 by emitting succinct forms where possible.
It also covers step 4 for the same direct mapping subset with
`ysc -t jsc`.
