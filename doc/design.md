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
contact.ysc.yaml -> contact.ysc.json -> contact.schema.json
```

- `.ysc.yaml` is the human-maintained yamlschema DSL form.
- `.ysc.json` is the compiled, expanded yamlschema form.
- `.schema.json` is the JSON Schema export or import form.

The `.ysc.yaml` form is ordinary YAML and should be pleasant to edit by hand.
The `.ysc.json` form is JSON data and is the long form intended for validators,
caches, publication, and generated artifacts.
The `.schema.json` form is the JSON Schema representation used for interop with
the JSON Schema ecosystem.


## Core Model

### Shape Mirrors Data

A mapping in a schema describes a mapping in the data:

```yaml
name: +Str
email?: /^\S+@\S+$/
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
for definitions or `-` for directives.


### Required By Default

Fields are required unless marked optional:

```yaml
name: +Str       # required
email?: +Str     # optional
```

The optional marker is part of the key syntax.
In the explicit model, optional fields omit `-need`.


### Constraints Imply Types

The succinct syntax avoids repeating type information when the constraint
already implies it:

```yaml
email: /^\S+@\S+$/      # string matching regex
role: admin|user|guest  # enum
port: 1-65535           # numeric range
tags[+]: +Str           # list of one or more strings
```

The corresponding explicit form uses directives such as `-like`, `-enum`,
`-size`, `-list`, and `-type`.


## Symbols and Definitions

Symbols begin with `+`.

```yaml
+email: /^\S+@\S+$/
+port: 1-65535

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
+Map
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

Directives begin with `-`.
The design keeps directive names short and regular.

| Directive | Meaning |
| --- | --- |
| `-need` | Required field marker; may carry a type or symbol |
| `-type` | Base type or inherited symbol |
| `-like` | Regex pattern; implies string |
| `-enum` | Enumeration of allowed values |
| `-size` | Number, string, list, or map size |
| `-list` | Value is a sequence |
| `-solo` | A scalar is also accepted where a list is declared |
| `-also` | Alternate key names |
| `-pick` | Mutually exclusive group alternatives |
| `-with` | Co-dependent keys |
| `-when` | Conditional requirement or constraint |
| `-init` | Default value |
| `-uniq` | List items must be unique |
| `-null` | Null is accepted |

Meta directives are top-level schema metadata:

| Directive | Meaning |
| --- | --- |
| `-from` | Import schemas or namespaces |
| `-name` | Name of a document schema |
| `-root` | Primary exported root type |


## Succinct Values

### Built-in Types

```yaml
name: +Str
age: +Int
ratio: +Float
enabled: +Bool
metadata: +Map
anything: +Any
```


### Regex

Regex values are delimited with `/`:

```yaml
email: /^\S+@\S+$/
zip: /^\d{5}(-\d{4})?$/
```

Equivalent explicit form:

```yaml
email:
  -like: /^\S+@\S+$/
zip:
  -like: /^\d{5}(-\d{4})?$/
```


### Enums

Simple enum values can be written with `|`:

```yaml
role: admin|user|guest
level: LOW|MED|HIGH
```

Equivalent explicit form:

```yaml
role:
  -enum: [admin, user, guest]
level:
  -enum: [LOW, MED, HIGH]
```

Values that cannot safely be represented as pipe tokens use explicit `-enum`:

```yaml
label:
  -enum:
  - has space
  - ok
```


### Numeric Ranges

```yaml
port: 1-65535
age: 0-*
ratio: 0-1
```

Equivalent explicit form:

```yaml
port:
  -type: +Int
  -size: [1, 65535]
age:
  -type: +Int
  -size: [0, "*"]
ratio:
  -type: +Float
  -size: [0, 1]
```

`*` means unbounded.
In YAML output it may need quoting because bare `*` is YAML alias syntax.


### Literal Constants

A literal value can be used as a constant constraint:

```yaml
version: v1
kind: User
```

Equivalent explicit form:

```yaml
version:
  -type: v1
kind:
  -type: User
```

The current converter maps JSON Schema `const` values this way.


## Key Suffixes

Suffixes are attached to field names:

```text
name [list-or-size] ? ~ :
```

| Suffix | Meaning |
| --- | --- |
| `key:` | Required key |
| `key?:` | Optional key |
| `key~:` | Required key that may be null |
| `key?~:` | Optional key that may be null |
| `key[]:` | Required list |
| `key[]?:` | Optional list |
| `key[3]:` | List with exactly 3 items |
| `key[1-3]:` | List with 1 to 3 items |
| `key[+]:` | List with 1 or more items |
| `key[5+]:` | List with 5 or more items |
| `key[$]:` | Scalar or list |
| `key[$|+]:` | Scalar or list with 1 or more items |
| `key[$|1-3]:` | Scalar or list with 1 to 3 items |
| `key[!]:` | Unique list |
| `key[!+]:` | Unique list with 1 or more items |
| `key[!3]:` | Unique list with exactly 3 items |
| `key[!1-3]:` | Unique list with 1 to 3 items |
| `key|alias:` | Key with an alias |

Examples:

```yaml
tags[]: +Str
names[+]: +Str
triple[3]: +Int
subset[1-3]: +Str
unique_tags[!+]: +Str
```

Key suffix grammar:

```text
key_expr = name bracket? "?"? "~"? ":"
bracket  = "[" "!"? (quantity ("|$")? | "$" ("|" quantity)?) "]"
quantity = n | n "-" m | n "-*" | n "+" | "+" | empty
```


## Explicit Form

The explicit form represents all constraints with directives:

```yaml
port:
  -need: true
  -type: +Int
  -size: [1, 65535]

email:
  -like: /^\S+@\S+$/

tags:
  -need: true
  -type: +Str
  -list: true
  -size: [1, "*"]
  -uniq: true
```

For fields with a type reference, `-need` can carry the referenced type:

```yaml
port:
  -need: +port
```

This is equivalent to:

```yaml
port:
  -type: +port
  -need: true
```

Optional fields omit `-need`:

```yaml
port:
  -type: +port
```


## Type Inheritance

Custom definitions can inherit from other definitions:

```yaml
+port:
  -type: +Int
  -size: [1, 65535]

+secure-port:
  -type: +port
  -size: [443, 443]
```

Implicit typing applies where possible:

- `-like` implies `+Str`.
- `-enum` implies the common value type.
- A mapping shape implies `+Map`.
- Numeric `-size` constraints imply numeric types when no explicit type exists.

Use `-type` when a base type cannot be inferred or when inheriting from a
custom definition.


## Pick Groups

A sequence of maps can describe mutually exclusive alternatives:

```yaml
+auth:
- api_key: +Str
- token: +Str
- username: +Str
  password: +Str
```

Equivalent explicit form:

```yaml
+auth:
  -pick:
  - api_key: +Str
  - token: +Str
  - username: +Str
    password: +Str
```

This is the intended direction for JSON Schema `oneOf`, but the converter does
not fully implement it yet.


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
It may have `-name` and bare data keys.
Top-level `+symbols` are private by default.

```yaml
-from: https://yaml.org/schema/base/v1
-name: contact

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
-from: https://yaml.org/schema/base/v1

:+max: 65535

+port:
  -type: +Int
  -size: [1, +max]

+email: /^\S+@\S+$/
+hostname: /^[a-z0-9.-]+$/
```


## Imports

Imports use `-from`:

```yaml
-from: https://yaml.org/schema/base/v1
```

Multiple imports can be namespaced:

```yaml
-from:
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
--- !yaml:./contact.ysc.yaml
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
  age?: 0-*
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
    "-type": "+Int",
    "-size": [1, 65535]
  },
  "+auth": {
    "-pick": [
      {"api_key": {"-need": "+Str"}},
      {"token": {"-need": "+Str"}}
    ]
  },
  "host": {"-need": "+Str"},
  "port": {"-need": "+port"}
}
```


## JSON Schema Mapping

The `bin/ysc` converter is a bootstrap path from JSON Schema into
yamlschema.
It currently focuses on mappings that are direct and mostly lossless.
Input JSON Schema files should conventionally use `.schema.json`.
Generated human-facing yamlschema output should use `.ysc.yaml`.
The converter can also generate `.schema.json` from `.ysc.yaml` for the
same direct mapping subset.

| JSON Schema | yamlschema |
| --- | --- |
| `type: "string"` | `+Str` |
| `type: "integer"` | `+Int` |
| `type: "number"` | `+Float` |
| `type: "boolean"` | `+Bool` |
| `type: "null"` | `+Null` |
| `type: "object"` | `+Map` or a nested mapping shape |
| `properties` | Bare mapping keys |
| `required` | Default required keys; omitted names get `?` |
| `enum` | Pipe enum or `-enum` list |
| `pattern` | Regex literal or `-like` |
| `minimum` / `maximum` | Range scalar or `-size` |
| `minLength` / `maxLength` | `-size` on strings |
| `minItems` / `maxItems` | List suffix or `-size` |
| `minProperties` / `maxProperties` | `-size` on maps |
| `uniqueItems` | `!` list suffix or `-uniq` |
| `items` | List value type or `-item` |
| `const` | Literal value constraint |
| `default` | `-init` |
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
tags[!+]: +Str
```


## Converter Behavior

`bin/ysc` works in these stages:

1. Read JSON Schema from the required input path, or from stdin when the input
   is `-`.
2. Require either `-t` / `--to` or `-o` / `--output`.
3. Use `-t ysc.yaml` to parse input as JSON Schema and emit yamlschema.
4. Use `-t schema.json` to parse input as yamlschema and emit JSON Schema.
5. Build a YAMLScript data structure for the output document.
6. Prefer succinct scalar forms where possible.
7. Use explicit directive maps when a schema cannot be represented as one
   scalar.
8. Dump `ysc.yaml` results as YAML and `schema.json` results as JSON.
9. Post-process generated TODO sentinel keys into `# TODO: <keyword>` comments.
10. Insert a blank line between top-level definitions and the document body.

The converter emits TODO comments for JSON Schema features that still need
language design or implementation:

```yaml
auth:
  # TODO: oneOf
```

Current TODO keywords include:

```text
allOf anyOf oneOf not if then else dependentRequired dependentSchemas
patternProperties propertyNames prefixItems contains additionalProperties
unevaluatedItems unevaluatedProperties exclusiveMinimum exclusiveMaximum format
```


## Current Scope and Open Design

Implemented or directly represented by the design:

- Scalar built-ins.
- Required and optional object properties.
- Nested object properties.
- Regex patterns.
- Pipe enums and explicit enums.
- Numeric ranges.
- String/list/map sizes.
- Array item schemas for simple homogeneous arrays.
- Unique arrays.
- Constants and defaults.
- `$defs`, `definitions`, and `$ref`.

Still open or incomplete:

- `allOf`, `anyOf`, and `oneOf` semantics.
- `not`.
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
