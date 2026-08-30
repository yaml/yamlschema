# yamlschema-json-schema - JSON Schema interoperability

`YAMLSchema` is designed to interoperate with JSON Schema in both directions:

```text
contact.schema.json
  -> contact.ysd.yaml
  -> contact.ysdc.yaml or contact.ysdc.json
  -> contact.schema.json
```

The roundtrip goal is semantic equivalence, not byte-for-byte equality.
JSON Schema has many equivalent ways to express the same constraint, and
YAMLSchema has both succinct and explicit forms.
A roundtripped JSON Schema may normalize schema keyword positions or expand
equivalent forms while still validating the same data.
Property names, definition names, and arbitrary JSON object members retain
their input order through conversion and normalization.


## Roundtrip Model

There are three useful semantic representations.
Expanded YAMLSchema is canonical `.ysdc`, with YAML and JSON
serializations:

```text
contact.schema.json
  -> contact.ysd.yaml
  -> contact.ysdc.yaml or contact.ysdc.json
  -> contact.schema.json
```

The `.ysd.yaml` succinct form is optimized for humans:

```yaml
name: +Str
email?: +Str ~"\S+@\S+"
tags: +Str[!1+]
```

The `.ysdc.json` explicit form is one serialization of the canonical internal
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
YAMLSchema DSL files.
Use `.ysdc.yaml` or `.ysdc.json` for the same non-human, fully expanded
YAMLSchema model.


## Conversion Directions

`bin/ysd` implements all four direct conversion targets:

```text
contact.schema.json -> contact.ysd.yaml
contact.ysd.yaml -> contact.ysdc.yaml
contact.ysd.yaml -> contact.ysdc.json
contact.ysd.yaml -> contact.schema.json
```

The explicit form is the shared expansion boundary:

```text
contact.ysd.yaml -> contact.ysdc.yaml or contact.ysdc.json
contact.ysd.yaml -> contact.schema.json
```

The compiler targets the explicit form because succinct syntax is sugar.
Once succinct YAMLSchema has been expanded, JSON Schema generation is mostly a
directive-to-keyword mapping.


## Strict Editor Conversion

The browser editor enables its **Strict** checkbox after editable JSON Schema
successfully generates `.ysd` or `.ysdc`.
Selecting it closes every unconstrained mapping by removing `.open` directives
and `+Str: +Any` wildcard pairs.
Typed additional-property rules such as `+Str: +Str` and `+Map{+Str}` remain
unchanged.

Strict is available only while JSON Schema is the editable source.
It intentionally narrows schemas that rely on JSON Schema's open-object
default.
The editor immediately regenerates JSON Schema from the strict YAMLSchema,
emitting `additionalProperties: false` for the affected mapping shapes.
Once applied, Strict remains checked and disabled, so the narrowing cannot be
undone in the UI.
Editing the JSON Schema clears Strict and disables it during conversion.
It becomes available again after the edited schema successfully generates
YAMLSchema.


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

YAMLSchema marks optional keys locally:

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

The authoritative list and semantics of YAMLSchema built-ins are in the [DSL
built-in-types reference](dsl.md#built-in-types).
Their direct JSON Schema mappings are:

| JSON Schema | YAMLSchema |
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
The YAML-specific `+Float` type exports as JSON Schema `number`, but `ysd`
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

YAMLSchema:

```yaml
email: +Str ~"\S+@\S+"
zip: +Str ~"{digit}{5}"
```

Roundtrip notes:

- JSON Schema regexes are strings.
- .ysd `.match` is a whole-string match; canonicalization bookends its value
  with `^` and `$`.
- .ysd `.find` is an unanchored search and canonicalization preserves its
  value.
- Canonical .ysdc uses `.like` for both and exports its value unchanged as the
  JSON Schema `pattern`.
- `~"..."`, `~~"..."`, and their `match:"..."` and `find:"..."` aliases
  cannot contain `"`; use an explicit .ysd `.match` or `.find` property when
  needed.
  Generated .ysd uses `~"..."` for `.match` and `~~"..."` for `.find`.
- Generated .ysd renders both `\d` and `[0-9]` as `{digit}`.
  It renders `[A-Z]` and `[a-z]` as `{upper}` and `{lower}`.
  It renders `\+` as `{plus}`.
  `{digit}` exports as `[0-9]`.
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

Enums whose values have different JSON types use an expanded `+Any` block so
that strings resembling other YAML scalars remain distinct:

```yaml
enabled:
  .type: +Any
  .enum: ['true', 'false', true, false]
```


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

YAMLSchema:

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

Exclusive one-sided bounds use three dots:

```json
{
  "properties": {
    "positive": {
      "type": "number",
      "minimum": 0,
      "exclusiveMinimum": true
    },
    "underTen": {
      "type": "number",
      "maximum": 10,
      "exclusiveMaximum": true
    }
  }
}
```

```yaml
positive?: +Num 0...
underTen?: +Num ...10
```

Use `:xmin` and `:xmax` for bounded ranges:

```yaml
unit?: +Num 0..1 :xmin :xmax
```

The canonical form keeps the inclusive bounds in `.range` and records which
bounds are exclusive:

```yaml
unit?:
  .type: +Num
  .range: [0, 1]
  .xmin: true
  .xmax: true
```

`0...10` is ambiguous and is rejected.
Write `0..10 :xmin`, `0..10 :xmax`, or both modifiers instead.

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
- `.xmin: true` and `.xmax: true` require the corresponding `.range` bound
  and map to boolean `exclusiveMinimum` and `exclusiveMaximum` companions.
- Draft 4 style boolean exclusives import natively when the corresponding
  `minimum` or `maximum` is present.
- Modern numeric `exclusiveMinimum` and `exclusiveMaximum` values remain
  passthrough directives.
- `.size` on `+Str` maps to `minLength` and `maxLength`.
- `.size` on lists maps to `minItems` and `maxItems`.
- `.size` on maps maps to `minProperties` and `maxProperties`.
- `minProperties: 1` imports as `.size: 1+` on a mapping shape.
- A root `.size` constrains the number of properties in the document map.
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
names: +Str[!1+]
```

Roundtrip mapping:

| YAMLSchema | JSON Schema |
| --- | --- |
| `key: +Str[]` | `type: array`, `items: {type: string}` |
| `key: +Str[1+]` | plus `minItems: 1` |
| `key: +Int[3]` | plus `minItems: 3`, `maxItems: 3` |
| `key: +Str[1-3]` | plus `minItems: 1`, `maxItems: 3` |
| `key: +Str[!]` | plus `uniqueItems: true` |
| `key: +Str[!1+]` | plus `uniqueItems: true`, `minItems: 1` |


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

YAMLSchema:

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
in YAMLSchema.
Draft 4 root `id` imports as `.ysid` and normalizes to `$id`.

When the input is a file, generated JSON Schema also has a root `$comment`:

```json
"$comment": "DO NOT EDIT. THIS FILE GENERATED BY YAMLSCHEMA vX.Y.Z"
```

This generated note is transient. Import and normalized roundtrip discard it,
so it is never represented in YAMLSchema or copied back to JSON Schema.
Output generated from stdin omits the note because there is no input file.

Other JSON Schema metadata roundtrips through explicit YAMLSchema directives.
These fields do not affect validation, but keeping them preserves useful
schema metadata.

| JSON Schema | YAMLSchema |
| --- | --- |
| `$id` or Draft 4 root `id` | `.ysid` |
| `$anchor` | `.name` |
| `title` | `.title` |
| `description` | Trailing `"description"` or `.desc` |
| Known string `format` | `+JSON-Schema/format` |

`.ysid` is the first mapping entry in generated YAMLSchema.
`$anchor` becomes `.name` on the same schema node and exports back unchanged.
The definition key and anchor name remain independent, so `$defs.product`
with `$anchor: ProductSchema` becomes `+product` with
`.name: ProductSchema`.
The recognized Draft 2020-12 formats become qualified YAMLSchema types, such
as `+JSON-Schema/date`, `+JSON-Schema/email`, and `+JSON-Schema/uuid`.
A known format is converted this way only when its JSON Schema type is string,
which avoids adding a string constraint to an annotation-only schema.
Unknown formats and formats without a string type remain lossless passthrough
directives with a warning.
.ysd and both .ysdc serializations use `.ysd.yaml` to identify the source .ysd
document.
JSON Schema uses `.schema.json`.
Conversion replaces one of those recognized suffixes or appends the target
suffix when none is present.
Query strings and fragments are preserved.


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
+email: +Str ~"\S+@\S+"

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
- Every other `$ref` imports as `+Ref(reference)` when the exact reference is
  safe in the compact grammar, or as `.xref: reference` otherwise.
- A document containing named definitions but no root shape exports only
  metadata and `$defs`; it does not gain a root `type`, `properties`, or
  `additionalProperties` constraint.
- `.xref` preserves the exact reference string without fetching or resolving
  it and can be combined with sibling constraints.
- A singleton `allOf` containing only a reference normalizes to a sibling
  `$ref` under Draft 2020-12.
- A singleton `allOf` containing only an `anyOf` normalizes to a sibling
  `anyOf`.
- A referenced mapping refined by local properties puts `+name` under `.type`
  and keeps those property definitions as siblings.
- Exporting back to JSON Schema should prefer `$defs`.

For example, an external reference can stay succinct:

```yaml
author: +Ref(https://example.com/user-profile.schema.json)
```

Its canonical form is:

```yaml
author:
  .xref: https://example.com/user-profile.schema.json
```


## Nested Objects

Nested JSON Schema objects become nested YAMLSchema mappings:

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
Its value is any YAMLSchema value schema:

```yaml
labels:
  +Str: +Str
config:
  enabled?: +Bool
  +Str: +Any
```

Explicit JSON Schema values import as follows:

| JSON Schema | YAMLSchema |
| --- | --- |
| `additionalProperties: true` | Inherited openness or `+Str: +Any` |
| `additionalProperties: {"type":"string"}` | `+Map{+Str}` |
| `additionalProperties: {"$ref":"..."}` | `+Map{+name}` |
| constrained `additionalProperties` | `+Str: schema` |
| `additionalProperties: false` | No wildcard |

Generated .ysd starts with `.open: true` only when the root object permits
undeclared properties.
Otherwise mappings are closed by default.
A shaped mapping with omitted `additionalProperties` is open in JSON Schema.
Under a closed .ysd default, the importer represents that local openness with
a final `+Str: +Any` wildcard.
Under an open .ysd default, `additionalProperties: false` becomes
`.open: false`.

On export, an open shape omits `additionalProperties`, while a closed shape
gets `additionalProperties: false`.
An explicit `+Str: +Any` also omits `additionalProperties`, since the JSON
Schema default has the same semantics; other wildcard values emit the
corresponding schema.
Top-level `.open` controls the root mapping as well as the mapping shapes
defined beneath it.

Canonical .ysdc keeps `.open: true` only at the top.
It preserves `.open: false` where an open inherited default must be closed,
and uses a final `+Str: +Any` wildcard where a closed inherited default must
be opened.

An incomplete `+Map` requires sibling properties.
The importer emits a wildcard block for pure unconstrained open objects.
The `+Map{+Any}` shorthand remains valid input.

When named properties coexist with `additionalProperties`, the importer emits
an explicit wildcard after the named properties:

```yaml
labels:
  fixed?: +Str
  +Str: +Str
```

Map-valued `patternProperties` entries use slash-delimited keys and may
coexist with named properties and the wildcard:

```yaml
name?: +Str
/^x-/: +Any
+Str: +Str
```

The text between the first and last slash is copied exactly, without added
anchors or unescaping.
Pattern keys are never required, cannot use `.need`, and cannot appear in
`.keys` rules.
An exact property name beginning and ending with `/` conflicts with this
syntax and is rejected.
The legacy `.patternProperties` passthrough form remains available for
schemas with Boolean pattern values, which are not native YAMLSchema types.
The native and legacy forms cannot be mixed in one mapping.

`+Map{+Type}` accepts one built-in, user-defined, or namespaced reference.
It is shorthand for the future `+Map{+Str,+Type}` form.
Two-reference maps are reserved for YAML key schemas but are not implemented.
More complex value constraints continue to use explicit `+Str` syntax.

Generated `.ysd.yaml` begins with `# Converted from JSON Schema`.
Root annotations and `.open` follow, then each top-level `+type` definition is
preceded by a blank line.


## Schema Combinators

JSON Schema combinators round-trip through explicit directives:

| JSON Schema | YAMLSchema |
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

A root `oneOf` imports as document-level `.one`.
Its branches are partial root constraints, so they export without an implied
`type: object` or `additionalProperties` keyword:

```yaml
deviceType: +Str
.one:
- .xref: https://example.com/smartphone.schema.json
  deviceType?: +Str ==smartphone
- .xref: https://example.com/laptop.schema.json
  deviceType?: +Str ==laptop
```

The `.xref` and `deviceType` constraint in each branch are siblings in the
corresponding JSON Schema `oneOf` member.

Root `anyOf` branches made only from `properties` and `required` import as an
ordered `.keys` rule:

```yaml
.keys:
- .any:
  - token: +Str 8+
  - existingSecret: +Str 1+
```

Each branch is a partial mapping constraint rather than an object type.
One rule exports directly as `anyOf`.
Multiple `.keys` rules export as ordered members of `allOf`.

A `required` schema without a corresponding `properties` mapping cannot use
property-key requiredness.
Inside combinators, it is preserved as a `.required` interop directive:

```yaml
.one:
- .required: [Action]
- .required: [NotAction]
```


## Property Dependencies

JSON Schema `dependentRequired` maps to a property-local `:need(...)` clause:

```yaml
postOfficeBox?: +Str :need(streetAddress)
extendedAddress?: +Str :need(streetAddress)
```

The annotated property is the trigger.
Its dependency names are sibling properties that must also be present.
Multiple names are comma separated, and `:need()` preserves an empty list.

When a property value already needs an explicit block, or a dependency name
is not safe in a tight scalar, use `.need` with a flow sequence:

```yaml
extendedAddress?:
  .type: +Str
  .need: [streetAddress]
```

Dependency targets do not need declarations in the same object.
For now, importing JSON Schema requires every `dependentRequired` trigger to
exist in the same `properties` map.
Supporting undeclared triggers needs a future object-level representation.


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
YAMLSchema-native semantics.
Open design areas include:

| JSON Schema | Possible YAMLSchema direction |
| --- | --- |
| `if` / `then` / `else` | `.when` |
| `dependentSchemas` | Extended `.with` or conditional schema |
| `propertyNames` | Key constraints |
| `prefixItems` | Positional list schemas |
| `contains` | List membership constraints |
| `unevaluatedItems` | Strict list mode |
| `unevaluatedProperties` | Strict map mode |
| `format` | Semantic format annotations |

Likely out of scope or JSON Schema-specific:

- Dynamic references.
- Anchors.
- Vocabularies.
- Boolean schemas.
- Content/media validation.


## Information That May Not Roundtrip

Semantic roundtrip does not preserve every textual detail:

- JSON object key order is preserved where the conversion retains the object.
- Whitespace and comments in JSON Schema are not preserved.
- Equivalent JSON Schema spellings may normalize to one spelling.
- Explicit `additionalProperties: true` and an empty schema normalize to
  omission.
- An omitted type normalizes to `object` for `properties` and
  `patternProperties`, or to the inferred type of a non-empty homogeneous
  enum.
- Empty and heterogeneous enums, conflicting inferences, and other
  type-specific keywords remain untyped.
- `minProperties: 0` normalizes away because zero is the default.
- `definitions` should export back as `$defs`.
- Succinct YAMLSchema may expand to explicit YAMLSchema before JSON
  generation.
- A compact enum and an explicit `.enum` with the same values are equivalent.
- A one-element `.range` or `.size` sequence denotes a missing upper bound;
  generated .ysd uses `n..` or `n+` rather than the obsolete `*` marker.

Lossless source-preserving roundtrip would require storing source metadata in
addition to the schema semantics.

Use `-R` to roundtrip either JSON Schema or .ysd through the other format:

```sh
ysd -R values.schema.json
ysd -Rq values.schema.json
ysd -R values.ysd.yaml
ysd -Rq values.ysd.yaml
```

For JSON Schema input, `ysd` compares normalized JSON Schema before and after
conversion through .ysd.
For .ysd input, it compares canonical .ysd before and after conversion through
JSON Schema.
Canonical .ysd expands lexical defaults, normalizes equivalent open-map forms,
preserves mapping key order, and retains YAML-specific type distinctions.

An explicit `-f` selects the input format.
Without `-f`, a first non-whitespace character of `{` selects JSON Schema;
anything else selects .ysd.

The first command prints `OK` or a unified diff.
The quiet form prints nothing.
When `less` is available, the diff is displayed with `less -FRX`; otherwise it
is written directly to standard output.
Both forms return status 0 for a match and status 1 for a difference.
This is a normalized structural comparison, not proof of validation
equivalence.


## Roundtrip Paths

JSON Schema roundtripping follows this path:

1. Parse JSON Schema into explicit YAMLSchema.
2. Render explicit YAMLSchema as succinct syntax where safe.
3. Parse succinct YAMLSchema back to explicit YAMLSchema.
4. Generate JSON Schema from explicit YAMLSchema.
5. Normalize both JSON Schema documents.
6. Compare the normalized documents.

.ysd roundtripping reverses that path:

1. Parse and canonicalize the original .ysd.
2. Generate JSON Schema from the .ysd.
3. Parse the generated JSON Schema.
4. Render it back to .ysd.
5. Canonicalize the generated .ysd.
6. Compare the canonical documents.
