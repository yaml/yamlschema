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

There are three useful semantic representations.
Expanded yamlschema has YAML and JSON serializations:

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
tags: +Str[1+,!]
```

The `.ysc.json` explicit form is one serialization of the canonical internal
shape:

```json
{
  "name": "+Str",
  "email?": {".type": "+Str", ".like": "^\\S+@\\S+$"},
  "tags": {
    ".type": "+Str[]",
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
yamlschema DSL files.
Use `.ysc.yaml` or `.ysc.json` for the same non-human, fully expanded
yamlschema model.


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


## JSON Schema Type Mapping

The authoritative list and semantics of yamlschema built-ins are in the [DSL
built-in-types reference](dsl.md#built-in-types).
Their direct JSON Schema mappings are:

| JSON Schema | yamlschema |
| --- | --- |
| `{"type": "string"}` | `+Str` |
| `{"type": "integer"}` | `+Int` |
| `{"type": "number"}` | `+Num` |
| `{"type": "boolean"}` | `+Bool` |
| `{"type": "null"}` | `+Null` |
| `{"type": "object"}` | `+Map{+Any}` or a mapping shape |
| `{"type": "array"}` | `+Any[]` or another value-side `+Type[]` |
| `{"type": ["string", "integer"]}` | `+Any(+Str,+Int)` |

JSON Schema `number` accepts integer and non-integer numeric values, so it maps
to `+Num`.
The YAML-specific `+Float` type exports as JSON Schema `number`, but `ysc`
warns because the exported schema also accepts integers.

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
n: +Num
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
- YSD `.match` is a whole-string match; canonicalization bookends its value
  with `^` and `$`.
- YSD `.find` is an unanchored search and canonicalization preserves its
  value.
- Canonical YSC uses `.like` for both and exports its value unchanged as the
  JSON Schema `pattern`.
- `/pattern/` is shorthand for `find:"pattern"` only when the body contains
  neither whitespace nor `/`.
- `=~"..."`, its accepted `match:"..."` alias, and `find:"..."` cannot contain
  `"`; use an explicit YSD `.match` or `.find` property when needed.
  Generated YSD uses `=~"..."` for `.match`.
- In any tight double-quoted body, `:\ ` represents colon-space and ` \#`
  represents space-hash.
  Other backslash sequences remain literal.
- All regex forms imply string validation.


## Enums

Simple token enums roundtrip through a type-qualified compact list:

```json
{
  "properties": {
    "role": {"enum": ["admin", "user", "guest"]}
  },
  "required": ["role"]
}
```

```yaml
role: +Str [admin, user, guest]
```

An enum default is marked on its member:

```yaml
logLevel: +Str [debug, =info, warning, error, fatal]
```

This expands to `.enum: [debug, info, warning, error, fatal]` plus `.init:
info`.

Compact members may contain whitespace; surrounding whitespace is trimmed and
interior whitespace is preserved.
Thus `[foo,bar,foo bar]` and `[ foo, bar, foo bar ]` are equivalent.
Quoted members and punctuation other than `.`, `-`, `_`, and `+` use explicit
`.enum`:

```json
{
  "properties": {
    "symbol": {"enum": ["ok", "bad/value"]}
  },
  "required": ["symbol"]
}
```

```yaml
symbol:
  .type: +Str
  .enum: [ok, bad/value]
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

`==value` maps to `const`; `=="foo bar"` is the quoted form and `const:value`
is the labeled alternative.
A following `=value` independently adds JSON Schema `default`:

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
port: +Int 1..65535
age: +Int 0..
ratio: +Num 0..1
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
bio: +Str 1-500
code: +Str 3+
```

Roundtrip rule:

- `.range` on `+Int`, `+Float`, or `+Num` maps its optional bounds to
  `minimum` and `maximum`.
- `.size` on `+Str` maps to `minLength` and `maxLength`.
- `.size` on lists maps to `minItems` and `maxItems`.
- `.size` on maps maps to `minProperties` and `maxProperties`.
- A one-number canonical sequence such as `.size: [3]` means that the upper
  bound is absent.


## Arrays

Homogeneous arrays use suffixes on the value type:

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
tags: +Str[]
names: +Str[1+]
triple: +Int[3]
subset: +Str[1-3]
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
names: +Str[1+,!]
```

Roundtrip mapping:

| yamlschema | JSON Schema |
| --- | --- |
| `key: +Str[]` | `type: array`, `items: {type: string}` |
| `key: +Str[1+]` | plus `minItems: 1` |
| `key: +Int[3]` | plus `minItems: 3`, `maxItems: 3` |
| `key: +Str[1-3]` | plus `minItems: 1`, `maxItems: 3` |
| `key: +Str[!]` | plus `uniqueItems: true` |
| `key: +Str[1+,!]` | plus `uniqueItems: true`, `minItems: 1` |


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
port: +Int =8080
host: +Str =localhost
```

Roundtrip rule: `.init` maps to JSON Schema `default`.


## Annotations

Generated `.schema.json` uses JSON Schema Draft 2020-12.
The converter accepts the recognized Draft 4, 6, 7, 2019-09, and 2020-12
dialect identifiers for the direct mappings it supports.
The `$schema` keyword is implied by `.schema.json` output and is not encoded
in yamlschema.

Other JSON Schema metadata roundtrips through explicit yamlschema directives.
These fields do not affect validation, but keeping them preserves useful
schema metadata.

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
+port: +Int 1..65535
+email: +Str =~"\S+@\S+"

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
| `additionalProperties: true` | `+Map{+Any}` |
| `additionalProperties: {"type":"string"}` | `+Map{+Str}` |
| `additionalProperties: {"$ref":"..."}` | `+Map{+name}` |
| constrained `additionalProperties` | `+Str: schema` |
| `additionalProperties: false` | No wildcard |

Generated YSD starts with `.open: true`, matching JSON Schema's default that
undeclared object properties are allowed.
A shaped mapping with omitted `additionalProperties` inherits that setting.
A nested `additionalProperties: false` becomes `.open: false`; a mapping
nested below that closed scope is locally reopened when its own JSON Schema
omits `additionalProperties`.

On export, an open shape omits `additionalProperties`, while a closed shape
gets `additionalProperties: false`.
An explicit `+Str: +Any` also omits `additionalProperties`, since the JSON
Schema default has the same semantics; other wildcard values emit the
corresponding schema.
The root yamlschema document remains closed without a wildcard: top-level
`.open` is the lexical default for the types defined beneath it.

Canonical YSC does not depend on surrounding lexical state.
Expansion places `.open: true` on each inherited open mapping shape and uses
the ordinary closed default for the rest.

An incomplete `+Map` requires sibling properties.
Pure open objects use `+Map{+Any}`.

When named properties coexist with `additionalProperties`, the importer emits
an explicit wildcard after the named properties:

```yaml
labels:
  fixed?: +Str
  +Str: +Str
```

`+Map{+Type}` accepts one built-in, user-defined, or namespaced reference.
It is shorthand for the future `+Map{+Str,+Type}` form.
Two-reference maps are reserved for YAML key schemas but are not implemented.
More complex value constraints continue to use explicit `+Str` syntax.

Generated `.ysd.yaml` begins with `# Converted from JSON Schema`.
Root annotations and `.open` follow, then each top-level `+type` definition is
preceded by a blank line.


## Schema Combinators

JSON Schema combinators round-trip through explicit directives:

| JSON Schema | yamlschema |
| --- | --- |
| `oneOf` | `.one` or `+One(...)` |
| `anyOf` | `.any` or `+Any(...)` |
| `allOf` | `.all` or `+All(...)` |
| `not` | `.not` or `+Not(...)` |

The compact forms contain type references only.
`One`, `Any`, and `All` require at least two references.
`Not` requires at least one; multiple references mean `not(anyOf(...))`.

When every `+Any(...)` branch is a simple built-in type, JSON Schema output
uses a `type` array.
References and richer alternatives use `anyOf`.


## Unsupported or Open JSON Schema Features

The converter keeps unsupported keywords as same-named dotted directives and
warns for every occurrence.
Their values remain data and export under the original JSON Schema keyword
rather than being converted into comments:

```yaml
auth?:
  .if:
    required:
    - token
```

These passthrough directives preserve information but do not yet provide
yamlschema-native semantics.
Open design areas include:

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
- Explicit `additionalProperties: true` normalizes to omission.
- `definitions` should export back as `$defs`.
- Succinct yamlschema may expand to explicit yamlschema before JSON
  generation.
- A compact enum and an explicit `.enum` with the same values are equivalent.
- A one-element `.range` or `.size` sequence denotes a missing upper bound;
  generated YSD uses `n..` or `n+` rather than the obsolete `*` marker.

Lossless source-preserving roundtrip would require storing source metadata in
addition to the schema semantics.

Use `-R` to compare normalized JSON Schema before and after the serialized YSD
roundtrip:

```sh
ysc -R values.schema.json
ysc -Rq values.schema.json
```

The first command prints `OK` or a unified diff.
The quiet form prints nothing.
When `less` is available, the diff is displayed with `less -FRX`; otherwise it
is written directly to standard output.
Both forms return status 0 for a match and status 1 for a difference.
This is a normalized structural comparison, not proof of validation
equivalence.


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
It also covers step 4 for the same direct mapping subset with `ysc -t jsc`.
