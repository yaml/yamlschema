yamlschema Design
=================

`yamlschema` is a YAML-native data validation schema language.
A schema is itself YAML, and its shape mirrors the YAML data it validates.
The language has two layers:

- A succinct form meant for people to author and read.
- An explicit directive form meant to be canonical and mechanically produced.

Every succinct form should expand to explicit directives.
Validators can consume the explicit form directly, while humans can write the
compact form.


## File Extensions

yamlschema uses separate extensions for human-authored source, compiled
yamlschema, and JSON Schema interchange.

```text
contact.ysd.yaml -> contact.ysc.yaml or contact.ysc.json
contact.ysd.yaml -> contact.schema.json
```

- `.ysd.yaml` is the human-maintained yamlschema DSL form.
- `.ysc.yaml` is the expanded yamlschema form serialized as YAML.
- `.ysc.json` is the expanded yamlschema form serialized as JSON.
- `.schema.json` is the JSON Schema export or import form.

The `.ysd.yaml` form is ordinary YAML and should be pleasant to edit by hand.
The `ysc` forms contain the same non-human, fully expanded data and are
intended for validators, caches, publication, and generated artifacts.
The `.schema.json` form is the JSON Schema representation used for interop with
the JSON Schema ecosystem.


## Core Model

### Shape Mirrors Data

A mapping in a schema describes a mapping in the data:

```yaml
name: +Str
email?: +Str =~"\S+@\S+"
address:
  street: +Str
  city: +Str
```

This describes data like:

```yaml
name: Alice
email: alice@example.com
address:
  street: 1 Main St
  city: Toronto
```

Schema keys are data keys unless they start with a reserved prefix such as `+`
for definitions or `.` for directives.


### Required By Default

Fields are required unless marked optional:

```yaml
name: +Str       # required
email?: +Str     # optional
```

The optional marker is part of the key syntax.
The optional marker remains on the key in the canonical explicit model.
`.need` is reserved until requiredness has a separate final design.


### Constraints Imply Types

The succinct syntax avoids repeating type information when the constraint
already implies it:

```yaml
email: +Str =~"\S+@\S+"  # whole-string regex match
role: +Str [admin,user,guest]  # enum with explicit type
port: 1..65535           # numeric range
tags: +Str[1+]          # list of one or more strings
```

The corresponding canonical form uses type references and directives such as
`.type`, `.like`, `.enum`, and `.size`.


## Symbols and Definitions

Symbols begin with `+`.

```yaml
+email: /^\S+@\S+$/
+port: 1..65535

admin_email: +email
listen_port: +port
```

Built-in symbols are uppercase:

```text
+Any
+Str
+Int
+Float
+Bool
+Null
+Map{+Type}
```

User-defined symbols are normally lowercase:

```yaml
+email: /^\S+@\S+$/
+address:
  street: +Str
  city: +Str
```

Definitions are declarative.
Order is not significant.
A symbol may refer to a base type, a regex, a range, an enum, a map shape, or
another schema construct.

Private definitions use `:+name` as the key and are still referenced as `+name`
inside the same schema:

```yaml
:+local-part: /[a-zA-Z0-9._%+-]+/
+email: /{+local-part}@example\.com/
```

Namespaced references are written with `/`:

```yaml
server:
  port: +net/port
  email: +contact/email
```


## Directives

Directives begin with `.`.
The design keeps directive names short and regular.

| Directive | Meaning |
| --- | --- |
| `.need` | Reserved; currently rejected in favor of key-side `?` |
| `.type` | Complete built-in or named type expression |
| `.like` | Canonical raw regex pattern; implies string |
| `.match` | YSD whole-string regex; canonicalization adds `^` and `$` |
| `.find` | YSD regex search; canonicalization preserves the pattern |
| `.enum` | Enumeration of allowed values |
| `.const` | The one exact allowed value; JSON Schema `const` |
| `.range` | Inclusive numeric range, with either bound optional |
| `.size` | Number, string, list, or map size |
| `.item` | Explicit sequence item type |
| `.one` | Exactly one alternative must match |
| `.any` | One or more alternatives must match |
| `.all` | Every alternative must match |
| `.not` | The nested type must not match |
| `.solo` | A scalar is also accepted where a list is declared |
| `.uniq` | List items must be unique |
| `.null` | Null is accepted |
| `.init` | Default value |
| `.title` | Human-facing display title |
| `.desc` | Description annotation |
| `.also` | Alternate key names |
| `.with` | Co-dependent keys |
| `.when` | Conditional requirement or constraint |

Meta directives are top-level schema metadata:

| Directive | Meaning |
| --- | --- |
| `.from` | Import schemas or namespaces |
| `.name` | Name of a document schema |
| `.root` | Primary exported root type |
| `.json` | JSON Schema interop metadata |
| `.title` | Human-facing display title |
| `.desc` | JSON Schema `description` annotation |


## Succinct Values

A succinct value is a YAML plain scalar. A type reference is conventionally
first, and labeled clauses can occur in any order. The scalar labels are
`type`, `match`, `find`, `const`, `range`, `size`, `list`, `item`,
`solo`, `uniq`, `null`, `init`, `title`, `desc`, and scalar `also`.
`enum:[...]` uses the compact enum grammar. Structural `.one`, `.any`,
`.all`, `.not`, `.with`, and `.when` values remain explicit.

```yaml
foo: desc:"Words" size:1-3 =~"a b" title:"Title" type:+Str
```

The canonical explicit form uses the period-prefixed directive names. The old
names `titl`, `just`, and `only` are errors with diagnostics naming `title`
and `const`. The tight `like:` label is also rejected in favor of YSD
`match:` or `find:`; canonical YSC `.like` stores the resulting raw pattern.

### Descriptions

A schema scalar may end with a double-quoted description:

```yaml
repository?: +Str "Repository path without registry host"
right: +Str "This isn't wrong"
dbRepository?: +Str[] "Repositories for the vulnerability DB"
```

This expands to:

```yaml
repository?:
  .type: +Str
  .desc: Repository path without registry host
right:
  .type: +Str
  .desc: This isn't wrong
dbRepository?:
  .type: +Str[]
  .desc: Repositories for the vulnerability DB
```

The whole value is a YAML plain scalar.
The quote characters are yamlschema syntax, not YAML quoting syntax.
The description starts after the schema expression and opening double quote.
It ends at the scalar's final double quote.
The two outer quote characters are removed. Inside them, `:\ ` represents
colon-space and ` \#` represents space-hash so the containing YAML value can
remain a plain scalar. These are exact triplets: `foo\ bar`, `\n`, and `\t`
remain literal. Internal double quotes are not representable.
List suffixes may follow the schema expression before the description.

YAML plain-scalar folding is allowed:

```yaml
repository?: +Str
  "Repository path without registry host"
```

A YAML-quoted scalar such as `"Description"` loses its quote style when loaded
and therefore is not this shorthand.
Descriptions that cannot be safely represented in a YAML plain scalar use the
explicit `.desc` form.


### Built-in Types

```yaml
name: +Str
age: +Int
ratio: +Float
enabled: +Bool
metadata: +Map{+Any}
anything: +Any
```


### Regex

Use `=~"..."` for a whole-string match. `match:"..."` is also accepted:

```yaml
email: +Str =~"\S+@\S+"
zip: +Str =~"\d{5}(-\d{4})?"
```

Equivalent canonical YSC form:

```yaml
email:
  .type: +Str
  .like: ^\S+@\S+$
zip:
  .type: +Str
  .like: ^\d{5}(-\d{4})?$
```

Use `find:"..."` for an unanchored search. `/pattern/` is its compact form
when `pattern` contains neither whitespace nor `/`:

```yaml
word: /good/
path: find:"usr/local"
```


### Enums

Simple enum values use an explicit type and a compact list:

```yaml
role: +Str [admin,user,guest]
level: +Str [LOW,MED,HIGH]
logLevel: +Str [debug,=info,warning,error,fatal]
```

Equivalent explicit form:

```yaml
role:
  .type: +Str
  .enum: [admin, user, guest]
level:
  .type: +Str
  .enum: [LOW, MED, HIGH]
```

Compact members may contain letters, digits, whitespace, `.`, `-`, `_`, and
`+`. Whitespace surrounding members is trimmed and interior whitespace is
preserved. A leading `=` marks the one member that is also the default. Quoted
or otherwise punctuated values use explicit `.enum`:

```yaml
label: +Str [has space,ok]
symbol:
  .type: +Str
  .enum: [ok, bad/value]
```


### Numeric Ranges

```yaml
port: +Int 1..65535
age: +Int 0..
ratio: +Float 0..1
```

Equivalent explicit form:

```yaml
port:
  .type: +Int
  .range: [1, 65535]
age:
  .type: +Int
  .range: [0]
ratio:
  .type: +Float
  .range: [0, 1]
```


### Literal Constants

A type-qualified `==` clause is a constant constraint:

```yaml
version: +Str ==v1
kind: +Str ==User
label: +Str =="foo bar"
```

Equivalent explicit form:

```yaml
version:
  .type: +Str
  .const: v1
kind:
  .type: +Str
  .const: User
```

`const:User` is the labeled alternative. `=User` is independently a default,
so `+Str ==User =User` exports both `const` and `default`.


## Property Keys

The property key syntax carries only pair-level optionality:

```text
name ? :
```

| Form | Meaning |
| --- | --- |
| `key:` | Required key |
| `key?:` | Optional key |

Lists, sizes, uniqueness, and scalar-or-list constraints belong to the value
type:

```yaml
tags: +Str[]
names: +Str[1+]
triple: +Int[3]
subset: +Str[1-3]
unique_tags: +Str[1+,!]
```

The complete property-key grammar is:

```text
key_expr = name "?"? ":"
```

Key-side list syntax such as `key[]` and `key?[1+]` is rejected.


## Key/Value Pair Constraints

Optionality belongs to one key/value pair, but some mapping constraints relate
several pairs. The properties remain ordinary sibling entries so their order
is preserved. A planned `.keys` sequence holds ordered relationship rules:

```yaml
aaa: +Bool
foo?: +Str
fool?: +Int
bar?: +Str
baz?: +Int
bbb: +bar

.keys:
- .one: [foo, fool]
- .one: [bar, baz]
```

Each `.one` rule requires exactly one named property. Repeating `.one` is
valid because every rule is a separate mapping in the sequence; YAML duplicate
keys are not required.

Other presence relationships fit the same ordered rule model:

```yaml
.keys:
- .any: [host, socket, url]
- .excl: [debug, quiet]
- .with:
    user: [password]
- .when: key1
  .then: [key2]
  .else: [key3]
```

`.any` requires at least one property, `.excl` permits at most one, and
`.with` declares dependent required properties. `.when` tests whether its
property is present; `.then` and `.else` select additional required
properties. For example, the last rule corresponds to JSON Schema `if` with
`required: [key1]`, followed by `then` and `else` schemas requiring `key2` or
`key3`.

This `.keys` rule system is design-only for now. It is not accepted by the
converter yet.


## Wildcard Keys

Mappings with declared keys are closed by default.
Use the reserved `+Str` key to allow otherwise-unmatched string keys and
constrain their values:

```yaml
labels:
  +Str: +Str
config:
  known?: +Bool
  +Str: +Any
```

The first mapping accepts any string key with a string value.
The second accepts `known` plus any other string key with any value.
Pure arbitrary mappings use `+Map{+Any}`.

The succinct typed-map form constrains values for otherwise-unmatched string
keys:

```yaml
config: +Map{+Any}
labels: +Map{+Str}
custom: +Map{+value}
```

It expands to the existing canonical wildcard model:

```yaml
labels:
  +Str: +Str
```

`+Map` is an incomplete mapping type that requires sibling key/value pairs.
`+Map[]` is therefore a list of shaped mappings whose item properties follow
as siblings. The complete open form `+Map{+Value}` is shorthand for
`+Map{+Str,+Value}`. The two-reference form is reserved for future YAML key
schemas but is not implemented yet.

```yaml
extraEnv?:
  .type: +Map[1-10,$!]
  name: +Str
  value?: +Str
  valueFrom?: +Map{+Any}
```

This is a scalar or unique list of one through ten closed mapping values. The
sibling pairs complete the list item shape. In list brackets, size, `$`, and
`!` are independent properties. Commas, whitespace, and adjacency are
accepted separators, while generated YSD uses canonical `[size,$!]` order.


## Explicit Form

The canonical explicit form represents all constraints with directives:

```yaml
port:
  .type: +Int
  .range: [1, 65535]

email:
  .type: +Str
  .like: ^\S+@\S+$

tags:
  .type: +Str[]
  .size: [1]
  .uniq: true
```

Optional fields retain `?` on the key:

```yaml
port?: +port
```


## Base Inheritance

Custom definitions can inherit from other definitions:

```yaml
+port:
  .type: +Int
  .range: [1, 65535]

+secure-port:
  .type: +port
  .range: [443, 443]
```

Implicit typing applies where possible:

- `.like` implies `+Str` in canonical YSC; YSD `.match` and `.find` normalize
  to `.like`.
- `.enum` implies the common value type.
- A mapping shape implies the mapping type without emitting a base marker.
- Numeric range syntax implies `+Int` or `+Float` when no explicit type exists.

Emit an unrefined built-in or named reference as a `+Type` scalar when it is
the type's entire value. Use `.type` when the reference or complete tight type
expression shares a mapping with annotations, constraints, or shape entries.


## Schema Combinators

Compact combinators contain type references:

```yaml
+scalar: +One[+Str,+Int]
+value: +Any[+foo,+bar]
+both: +All[+foo,+bar]
+neither: +Not[+foo,+bar]
```

`One`, `Any`, and `All` require two or more references. `Not` requires one or
more and excludes every listed type. Complete branch definitions use the
explicit form:

```yaml
+auth:
  .one:
  - api_key: +Str
  - token: +Str
  - username: +Str
    password: +Str
```

Multiple unbracketed references are conjunctive. The first becomes `.type` and
the remaining references become `.all` branches.


## Regex Composition

Regex-valued definitions can be composed by reference:

```yaml
:+user: /[a-zA-Z0-9._%+-]+/
:+host: /[a-zA-Z0-9.-]+/
:+tld: /[a-zA-Z]{2,}/

+email: /^{+user}@{+host}\.{+tld}$/
```

The composed result expands to:

```yaml
+email: /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
```

Rules:

- Referenced regexes have their `/` delimiters removed.
- Leading `^` and trailing `$` anchors are stripped before inlining.
- References must resolve to regex-valued definitions.
- Circular references are errors.


## Schema File Types

### Document Schema

A document schema exports one shape.
It may have `.name` and bare data keys.
Top-level `+symbols` are private by default.

```yaml
.from: https://yaml.org/schema/base/v1
.name: contact

+email: /^\S+@\S+$/

name: +Str
email?: +email
address:
  street: +Str
  city: +Str
  zip: /^\d{5}$/
```


### Type Library

A type library exports symbols.
It has no bare data keys.
Public symbols use `+name`; private symbols use `:+name`.

```yaml
.from: https://yaml.org/schema/base/v1

:+max: 65535

+port:
  .type: +Int
  .size: [1, +max]

+email: /^\S+@\S+$/
+hostname: /^[a-z0-9.-]+$/
```


## Imports

Imports use `.from`:

```yaml
.from: https://yaml.org/schema/base/v1
```

Multiple imports can be namespaced:

```yaml
.from:
  net: https://yaml.org/schema/net/v1
  <: https://yaml.org/schema/base/v1

server:
  port: +net/port
  host: +Str
```

`<` means import exported names without a namespace prefix.


## Binding Data to Schemas

The language does not require one binding mechanism.
Applications can decide how documents declare or receive schemas.

One option is a document tag:

```yaml
--- !yaml://yaml.org/schema/contact/v1
name: Alice
```

Relative and application-local names are also possible:

```yaml
--- !yaml:./contact.ysd.yaml
name: Alice

--- !yaml:contact/v1
name: Alice
```

Another option is a `!!yaml` meta document:

```yaml
--- !!yaml
schema: yaml://yaml.org/schema/contact/v1
strict: true
format:
  indent: 2
---
name: Alice
email: alice@example.com
```

Inline schema is also possible:

```yaml
--- !!yaml
schema:
  name: +Str
  age?: 0..
  email?: /^\S+@\S+$/
---
name: Alice
age: 30
```

Loader configuration is application-defined.
It can cover validation, strictness, unknown keys, security limits, tag
resolution, duplicate keys, merge keys, coercion, null handling, and dumping
style.


## Compiled Output

Published schemas are expected to compile to a fully expanded JSON-compatible
form.
The succinct YAML form is for authors; the expanded form is for validators and
interchange.

Workflow:

```text
author succinct YAML -> compile explicit form -> publish JSON -> validate data
```

Example compiled shape:

```json
{
  "+port": {
    ".type": "+Int",
    ".range": [1, 65535]
  },
  "+auth": {
    ".one": [
      {"api_key": "+Str"},
      {"token": "+Str"}
    ]
  },
  "host": "+Str",
  "port": "+port"
}
```


## JSON Schema Mapping

The `bin/ysc` converter is a bootstrap path from JSON Schema into
yamlschema.
It currently focuses on mappings that are direct and mostly lossless.
Input JSON Schema files should conventionally use `.schema.json`.
Generated human-facing yamlschema output should use `.ysd.yaml`.
Expanded yamlschema should use `.ysc.yaml` or `.ysc.json`; both contain the
same canonical model.
The converter can also generate `.schema.json` from `.ysd.yaml` for the
same direct mapping subset.
The `.schema.json` target currently uses JSON Schema Draft 2020-12 only.
The `$schema` keyword is implied by the target and is not encoded in
yamlschema.

| JSON Schema | yamlschema |
| --- | --- |
| `type: "string"` | `+Str` |
| `type: "integer"` | `+Int` |
| `type: "number"` | `+Float` |
| `type: "boolean"` | `+Bool` |
| `type: "null"` | `+Null` |
| `type: "object"` | `+Map{+Any}` or a nested mapping shape |
| `properties` | Bare mapping keys |
| `required` | Default required keys; omitted names get `?` |
| `additionalProperties: true` | `+Map{+Any}` |
| simple schema-valued `additionalProperties` | `+Map{+Type}` |
| constrained `additionalProperties` | `+Str: schema` |
| `additionalProperties: false` | Closed mapping; no wildcard |
| `enum` | Compact enum or `.enum` list |
| `pattern` | `.match` for outer `^...$`; otherwise `.find` or `/.../` |
| `minimum` / `maximum` | Range scalar or structural `.range` sequence |
| `minLength` / `maxLength` | `.size` on strings |
| `minItems` / `maxItems` | List suffix or `.size` |
| `minProperties` / `maxProperties` | `.size` on maps |
| `uniqueItems` | `!` list suffix or `.uniq` |
| `items` | List value type or `.item` |
| `const` | Literal value constraint |
| `default` | `.init` |
| `description` | Trailing `"description"` or `.desc` |
| `title` | `.title` |
| `$id` | `.json.$id` |
| `$defs` / `definitions` | Top-level `+name` definitions |
| `$ref` | `+name` symbol reference |

Example:

```json
{
  "$defs": {
    "email": {"type": "string", "pattern": "^\\S+@\\S+$"}
  },
  "properties": {
    "name": {"type": "string"},
    "email": {"$ref": "#/$defs/email"},
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

Converts to:

```yaml
+email: /^\S+@\S+$/

name: +Str
email?: +email
tags: +Str[1+,!]
```


## Converter Behavior

`bin/ysc` works in these stages:

1. Read JSON Schema from the required input path, or from stdin when the input
   is `-`.
2. Require either `-t` / `--to` or `-o` / `--output`.
3. Use `-t ysd` to parse Draft 2020-12 JSON Schema and emit succinct
   yamlschema.
4. Use `-t yscy` or `-t yscj` to emit fully expanded yamlschema as YAML or
   JSON.
5. Use `-t jsc` to parse yamlschema and emit Draft 2020-12 JSON
   Schema.
6. Build a YAMLScript data structure for the output document.
7. Prefer succinct scalar forms where possible.
8. Use explicit directive maps when a schema cannot be represented as one
   scalar.
9. Dump `ysd.yaml` and `ysc.yaml` results as YAML. Dump `ysc.json` and
   `schema.json` results as canonical, two-space-indented JSON.
   Use `-C` / `--compact` for compact JSON output.
10. Post-process generated TODO sentinel keys into `# TODO: <keyword>`
    comments.
11. Insert a blank line between top-level definitions and the document body.

The converter emits TODO comments for JSON Schema features that still need
language design or implementation:

```yaml
auth:
  # TODO: if
```

Current TODO keywords include:

```text
if then else dependentRequired dependentSchemas patternProperties
propertyNames prefixItems contains
unevaluatedItems unevaluatedProperties exclusiveMinimum exclusiveMaximum format
```


## Current Scope and Open Design

Implemented or directly represented by the design:

- Scalar built-ins.
- Required and optional object properties.
- Nested object properties.
- Closed shaped mappings and typed wildcard keys.
- Regex patterns.
- Compact type-qualified enums and explicit enums.
- Numeric ranges.
- String/list/map sizes.
- Array item schemas for simple homogeneous arrays.
- Unique arrays.
- Constants and defaults.
- `allOf`, `anyOf`, `oneOf`, and `not` combinators.
- `$defs`, `definitions`, and `$ref`.

Still open or incomplete:

- `if` / `then` / `else`.
- Dependency constraints.
- Regex property names and pattern properties.
- Positional list schemas.
- `contains`, `minContains`, and `maxContains`.
- Unevaluated item/property handling.
- JSON Schema dynamic references, anchors, vocabularies, content validation,
  and
boolean schemas.

Some of those may become first-class yamlschema features; some may remain
outside the scope of the language.
