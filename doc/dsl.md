yamlschema DSL
==============

This page specifies the human-authored yamlschema DSL and its expansion to the
YSD Canonical (YSDC) model, serialized as `.ysdc.yaml` or `.ysdc.json`.
A schema defines types: sets of constraints for a scalar, mapping, or list of
another type.

The optional top-level `.ysid` is a non-empty document identity string:

```yaml
.ysid: https://example.com/contact.ysd.yaml
```

Generated output places `.ysid` first, although input may place it anywhere.
YSD and YSDC use `.ysd.yaml`, while JSON Schema uses `.schema.json`.
Conversion replaces a recognized suffix and appends the target suffix when
none is present.

The optional `.name` directive gives a schema node an externally addressable
name:

```yaml
.name: PersonSchema

+address:
  .name: AddressSchema
  street: +Str
```

At the document top it names the root schema.
Inside a definition or property type it names that schema node.
It maps directly to JSON Schema `$anchor`, while a definition key such as
`+address` remains the local YAMLSchema type name.
Names must match `[A-Za-z_][A-Za-z0-9._-]*` and must be unique in one schema
document.


## Types in Mappings

A normal mapping entry has the data key on the left and its type on the right:

```yaml
name: +Str
nickname?: +Str
```

Keys are required unless they end in `?`.
The `?` remains on the key in canonical yamlschema.
A value may be a reference, an anonymous type, or a reference refined by more
constraints:

```yaml
email: +email
code: +Str /[A-Z][0-9]+/
work_email: +email /@example\.com$/
```

Definitions use a `+slug` key.
The key names the type and references use the same slug:

```yaml
+resources:
  requests?: +Map{+Any}
  limits?: +Map{+Any}

resources?: +resources
```

Local references name definitions with `+name`.
External JSON Schema references use `+Ref(...)` and preserve the reference
text without fetching or resolving it:

```yaml
author: +Ref(https://example.com/user-profile.schema.json)
profile?: +Ref(../schemas/profile.json#/$defs/profile)
```

The compact form requires a non-empty reference without whitespace or `)`.
It accepts the normal list and nullable suffixes, such as `+Ref(#item)[]` and
`+Ref(profile.json)~`.
Use the canonical `.xref` directive for every other reference string or when
the reference has sibling constraints:

```yaml
author:
  .xref: https://example.com/user-profile.schema.json
  .desc: An externally defined author
empty:
  .xref: ''
```

`.xref` accepts any string and exports it unchanged as JSON Schema `$ref`.
It is separate from `.from`, which imports schemas or namespaces.

Anonymous mapping shapes need no `.type` marker.
Shaped mappings are closed by default; key-side `+Str` admits otherwise
unmatched string keys:

```yaml
labels:
  fixed?: +Str
  +Str: +Str
```

String-keyed maps can name their value type directly:

```yaml
config: +Map{+Any}
labels: +Map{+Str}
flags: +Map{+flag}
```

`+Map{+Type}` expands to `+Str: +Type`.
The value type must be one built-in, user-defined, or namespaced reference.
An incomplete `+Map` must be completed by sibling key/value pairs.

Lists of maps append the list suffix to the value type:

```yaml
maps: +Map{+Any}[]
other: +Map{+Str}[]
```

The reserved future form `+Map{+Key,+Value}` will support YAML key schemas.
It is not implemented yet.
The current one-reference form is shorthand for `+Map{+Str,+Value}` and
therefore fixes keys to strings.

Mappings are closed by default.
Top-level `.open: true` changes the default for the document mapping and every
mapping shape defined beneath it:

```yaml
.open: true

+person:
  name: +Str

server:
  .open: false
  host: +Str
```

Here the document and `+person` are open, while `server` and every mapping
shape nested beneath it are closed unless locally reopened.

A nested `.open` must be Boolean and overrides the inherited value.
An explicit `+Str` wildcard controls the current shape directly.
Combining `.open: false` with such a wildcard is an error.
Canonical YSDC keeps `.open: true` only at the document top.
It uses `.open: false` to close a shape under an open default and a final
`+Str: +Any` wildcard to open a shape under a closed default.


## Key/Value Pair Constraints

Use a top-level `.keys` sequence when a constraint relates multiple mapping
pairs:

```yaml
token?: +Str
existingSecret?: +Str

.keys:
- .any:
  - token: +Str 8+
  - existingSecret: +Str 1+
```

Each `.any` branch is a partial mapping constraint.
The example requires at least one branch to match: `token` must be present and
have at least eight characters, or `existingSecret` must be present and have
at least one character.

Plain branch keys are required.
A branch key ending in `?` is optional.
Unmentioned properties remain unaffected, and a branch does not create or
close an object type.

One `.keys` rule becomes a root JSON Schema `anyOf`.
Multiple rules all apply and become ordered members of a root `allOf`.
Each rule must currently contain exactly one `.any` entry with at least two
non-empty property-to-type mappings.


## Built-in Types

| Type | Accepted value |
| --- | --- |
| `+Any` | Any YAML value |
| `+Str` | A string |
| `+Int` | An integer |
| `+Float` | A YAML float-tagged value |
| `+Num` | Any numeric value: `+Int` or `+Float` |
| `+Bool` | `true` or `false` |
| `+Null` | `null` |
| `+Map` | A mapping shape completed by sibling property definitions |
| `+Map{+Type}` | A mapping with string keys and `+Type` values |

Capitalized type names are reserved for these built-ins and the `+One`,
`+All`, and `+Not` combinator heads.
A type reference beginning with a capital letter is rejected when it is not
one of those known names.
User-defined type references must not begin with a capital letter.

Examples:

```yaml
anything: +Any
name: +Str
age: +Int
ratio: +Float
number: +Num
enabled: +Bool
nothing: +Null
metadata: +Map{+Any}
labels: +Map{+Str}
person:
  .type: +Map
  name: +Str
  age?: +Int
```

`+Float` follows YAML tagging rather than JSON Schema numeric semantics.
It accepts float-tagged values such as `1.0`, `.inf`, and `.nan`, but not the
integer-tagged value `1`.
Use `+Num` when both integer- and float-tagged values are valid.

JSON Schema has no float-only numeric type.
Exporting `+Float` therefore emits `type: "number"` and a warning for that
loss of precision.

Bare `+Map` is intentionally incomplete.
It must have sibling property definitions, as in `person`, and its `.type`
marker disappears during canonical expansion because the mapping shape already
implies the type.
Use `+Map{+Any}` for an otherwise unconstrained string-keyed mapping, or
`+Map{+Type}` to constrain every value.
The future two-argument form `+Map{+Key,+Value}` is reserved for mappings
whose keys also have a schema.

Built-ins can be modified by the rest of the DSL.
`+Type[]` is a list of that type, `+Type~` also accepts null, and `+Any(...)`,
`+One(...)`, `+All(...)`, and `+Not(...)` combine referenced types.
These are type expressions built from the built-ins, not additional built-in
scalar types.


## Tight Type Expressions

A tight type expression is a YAML plain scalar.
A type reference is normally first, but labeled clauses may appear in any
order:

```text
+Base [(alternatives)] [list-suffix] [~] [pattern-or-range]
      [enum] [size] [constant] [default] [title] [description]
```

The core is normally a `+Type` reference, which later clauses refine:

```yaml
foo: +Str /a.*b/
port: +Int 1..65535
mode: +Str [debug, info, error]
```

A bare regex or numeric range can still infer a built-in type.
A fractional range infers `+Num` because its interval may include integers.
Generated YSD includes the inferred reference explicitly.

These expand to explicit directives.
Refined types are always materialized:

```yaml
foo:
  .type: +Str
  .like: a.*b
port:
  .type: +Int
  .range: [1, 65535]
mode:
  .type: +Str
  .enum: [debug, info, error]
```

`=~"pattern"` matches the complete string; leading `^` and trailing `$`
anchors are implied.
`match:"pattern"` is an accepted alias.
`find:"pattern"` searches within the string.
The `/pattern/` form is shorthand for `find:"pattern"` and is available only
when the pattern contains neither whitespace nor `/`.
The quoted bodies cannot contain `"`.
In YSD, use explicit `.match` or `.find` when no tight form can represent the
pattern.
Both imply `+Str`.
Generated YSD uses the canonical `=~"pattern"` spelling.

Canonical YSDC stores both forms as `.like`, containing the exact JSON Schema
pattern.
A match is bookended with `^` and `$`; a find is stored unchanged:

```yaml
whole:
  .type: +Str
  .like: ^pattern$
search:
  .type: +Str
  .like: pattern
```

`.like` is accepted only in `.ysdc.yaml` and `.ysdc.json`.
Conversely, `.match` and `.find` are YSD directives and are rejected in YSDC
input.

Compact enums require an explicit type reference and comma-separated members:

```yaml
mode: +Str [debug, info, error]
level: +Int [1, 2, 3]
logLevel: +Str [debug, =info, warning, error, fatal]
```

Members may contain letters, digits, whitespace, `.`, `-`, `_`, and `+`.
Whitespace around each comma-separated member is trimmed; whitespace inside a
member is preserved.
Thus `[foo,bar,foo bar]` and `[ foo, bar, foo bar ]` have the same meaning.
Quotes are not supported inside compact enums; use explicit `.enum` with a
YAML sequence for quoted or other punctuated values.
The base controls scalar parsing, so `+Str [true,1]` contains two strings.
Prefix one member with `=` to also set `.init` to that value.
At most one member may be marked.
Generated YSD uses one space after every compact-enum comma.

`+Str ==User` becomes `.const: User`, the exact-value constraint corresponding
to JSON Schema `const`.
`+Str =="foo bar"` is the quoted form, and `const:User` is the labeled
alternative.
A bare literal remains an accepted inferred-type shorthand.
It also means a constant, while `=value` means only a default.


## Lists and Sizes

List suffixes are part of the value-side type expression:

```yaml
names?: +Str[1+]
```

This expands to `.type: +Str[]` and `.size: [1]`.
The `[]` is part of the list type; `.size` carries its bounds.
Key-side list suffixes are rejected.

| Suffix | Meaning |
| --- | --- |
| `[]` | List with no size constraint |
| `[n]` | Exactly `n` items |
| `[n-m]` | Between `n` and `m` items |
| `[n+]` | At least `n` items |
| `[!]` | Unique items |
| `[$]` | Scalar or list |
| `[n-m,$!]` | Scalar or a unique list with the given size |

A list of shaped mappings uses the incomplete `+Map` base and defines the item
properties alongside it:

```yaml
extraEnv?:
  .type: +Map[1-10,$!]
  name: +Str
  value?: +Str
```

Here the value is either one mapping or a unique list of one through ten
mappings.
Each mapping has the sibling `name` and `value` properties.

List properties may be comma-separated, whitespace-separated, or adjacent.
For example, `[1-10,$!]`, `[1-10,$,!]`, `[1-10 $ !]`, and `[1-10$!]` are
equivalent.
Generated DSL uses the canonical `[size,$!]` order.
`[+]` is an input alias for `[1+]`.
The former `|` separator is rejected.
Multiple sizes or repeated `$` and `!` flags are errors.

A size clause also works after string, list, or mapping constraints:

```yaml
code: +Str 8
names: +Str[] 1+
labels: +Map{+Any} 1-20
```

Canonical sizes contain one number for an open upper bound and two for a
bounded or exact size:

```text
1+    -> [1]
10    -> [10, 10]
10-20 -> [10, 20]
```

Canonical ranges use the same structural convention, with `null` for a missing
lower bound:

```text
0..    -> [0]
1..10  -> [1, 10]
..-1   -> [null, -1]
```

The old `"*"` bound is invalid.


## Nulls and Annotations

Nullability is a value-side suffix:

```yaml
enabled?: +Bool~
```

Tight annotations follow all constraints:

```yaml
enabled?: +Bool~ =false title:"Enabled" "Enable the service"
label?: +Str ="pretty good"
mode?: type:+Str enum:[debug,info] init:info desc:"Log level"
```

- `=value` is a single YAML scalar default.
- `="..."` is a string default that may contain spaces.
- `title:"..."` is `.title`.
- A final `"..."` is `.desc`.
- Labeled scalar clauses may occur in any order.
  They are `type`, `match`, `find`, `const`, `range`, `size`, `item`, `solo`,
  `uniq`, `null`, `init`, `title`, `desc`, and scalar `also`.
- `enum:[...]` is the compact enum form.
- `:need(name1,name2)` lists sibling properties required when this property
  is present.
  Structural `.one`, `.any`, `.all`, `.not`, `.with`, and `.when` values
  remain explicit.

Two exact triplets protect text that YAML forbids in a plain scalar: `:\ `
represents colon-space, and ` \#` represents space-hash.
No other backslash sequence is special, so `foo\ bar`, `\n`, and `\t` remain
literal.
A body cannot contain a double quote.
Use the explicit directive when that is needed.
A scalar consisting entirely of a YAML-quoted string is a literal value, not
an annotation, because YAML does not preserve its original quote style.
The obsolete trailing single-quoted description form is an error.


## Hybrid Explicit Types

When one constraint is clearer explicitly, `.type` may contain the complete
tight expression and sibling directives add the exceptional parts:

```yaml
foo:
  .type: +Str[] /a.*b/ 10-20
  .title: The "Good" Parts
```

This is equivalent to:

```yaml
foo:
  .type: +Str[]
  .like: a.*b
  .size: [10, 20]
  .title: The "Good" Parts
```

Directive order is insignificant.
Expansion normalizes `.size` and emits a stable directive order.
A directive supplied by both the `.type` expression and a sibling is an error,
even when the values agree.


## Combinators

Reference-only alternatives have compact forms:

```yaml
one: +One(+Str,+Int)
any: +Any(+foo,+bar)
all: +All(+foo,+bar)
neither: +Not(+foo,+bar)
values: +Any(+foo,+bar)[]
```

`One`, `Any`, and `All` require at least two references.
`Not` requires at least one; multiple references mean the value must match
none of them.
A list suffix follows the complete combinator type.

Multiple references without parentheses are an implicit conjunction.
The first is the base and the rest are additional constraint groups:

```yaml
value: +base +constraint +other
```

Branches containing complete type definitions use explicit directives:

```yaml
value:
  .one:
  - +Str 1+
  - name: +Str
```

At the document root, `.one` constrains the root value in addition to its
declared properties:

```yaml
deviceType: +Str
.one:
- .xref: https://example.com/smartphone.schema.json
  deviceType?: +Str ==smartphone
- .xref: https://example.com/laptop.schema.json
  deviceType?: +Str ==laptop
```

Root branches are partial constraints, not standalone closed object types.
An optional property constrains that property when present without requiring
it again inside the branch.
Directives such as `.xref` apply alongside the branch properties.


## Canonical Expansion

Compile human-authored YAML to canonical JSON with:

```sh
ysd -t ysdc.json contact.ysd.yaml
ysd -t ysdc.json -C contact.ysd.yaml
ysd -t ysdc.json values.schema.json
```

Use `ysdc` or `ysdc.yaml` instead of `ysdc.json` for canonical YAML.
Use `-f/--from ysd`, `ysdc.json`, `ysdc`, or `jsc` when a filename or stdin does
not make the source format clear.
File suffixes `.ysd.yaml`, `.ysdc.json`, `.ysdc.yaml`, and `.schema.json` are
inferred automatically.

Canonical directives are emitted in this order:

```text
.name .type .xref .open .need .item .one .any .all .not .like
.enum .const .range .size .solo .uniq .null .init .title
.desc .also .with .when
```

An unrefined built-in or named reference is emitted directly as a `+Type`
scalar.
This is the compact form of a mapping whose only pair would be `.type: +Type`.
An external reference may similarly use `+Ref(...)`; its canonical form is
`.xref` rather than `.type`.
When annotations, validation constraints, or shape entries share the mapping,
the reference or complete tight expression remains under `.type`.

List types append `[]` to the reference.
An unconstrained list is therefore emitted as a scalar such as `+Any[]`;
constrained lists use forms such as `.type: +Str[]` with `.size` or `.uniq`.
`.list` is currently rejected and reserved for a possible future
list-constraint model; it does not mean "convert this type into a list."

Unknown directives are errors.
`.need` is valid only in a property definition and contains a sequence of
sibling property names.
For example, `.need: [password]` on `user` means that the presence of `user`
requires `password`.
`.also`, `.with`, and `.when` may be retained in explicit yamlschema, but an
export that cannot represent one fails rather than silently discarding it.
`.pick` and the former `.oneof`, `.anyof`, and `.allof` names are rejected
with guidance to use `.one`, `.any`, and `.all`.

The former names `.titl`, `.just`, `.only`, `.mini`, and `.maxi` are rejected
with replacement diagnostics.
Their replacements are `.title`, `.const`, and `.range`.
