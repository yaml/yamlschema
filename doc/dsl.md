yamlschema DSL
==============

This page specifies the human-authored yamlschema DSL and its expansion to the
canonical `ysc` model, serialized as `.ysc.yaml` or `.ysc.json`. A schema
defines types: sets of constraints for a scalar, mapping, or list of another
type.


## Types in Mappings

A normal mapping entry has the data key on the left and its type on the right:

```yaml
name: +Str
nickname?: +Str
```

Keys are required unless they end in `?`. The `?` remains on the key in
canonical yamlschema. A value may be a reference, an anonymous type, or a
reference refined by more constraints:

```yaml
email: +email
code: /[A-Z][0-9]+/
work_email: +email /@example\.com$/
```

Definitions use a `+slug` key. The key names the type and references use the
same slug:

```yaml
+resources:
  requests?: +Map{+Any}
  limits?: +Map{+Any}

resources?: +resources
```

Anonymous mapping shapes need no `.type` marker. Shaped mappings are closed;
key-side `+Str` admits otherwise unmatched string keys:

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

`+Map{+Type}` expands to `+Str: +Type`. The value type must be one built-in,
user-defined, or namespaced reference. An incomplete `+Map` must be completed
by sibling key/value pairs.

Lists of maps append the list suffix to the value type:

```yaml
maps: +Map{+Any}[]
other: +Map{+Str}[]
```

The reserved future form `+Map{+Key,+Value}` will support YAML key schemas.
It is not implemented yet. The current one-reference form is shorthand for
`+Map{+Str,+Value}` and therefore fixes keys to strings.


## Tight Type Expressions

A tight type expression is a YAML plain scalar. A type reference is normally
first, but labeled clauses may appear in any order:

```text
+Base [list] [null] [pattern-or-range] [enum] [size]
      [default] [title] [description]
```

The core is a `+Type` reference, regex, numeric range, or literal. A leading
reference may be refined:

```yaml
foo: +Str /a.*b/
port: +Int 1..65535
mode: +Str [debug,info,error]
```

These expand to explicit directives. Refined types are always materialized:

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
anchors are implied. `match:"pattern"` is an accepted alias. `find:"pattern"`
searches within the string. The `/pattern/` form is shorthand for
`find:"pattern"` and is available only when the pattern contains neither
whitespace nor `/`. The quoted bodies cannot contain `"`. In YSD, use explicit
`.match` or `.find` when no tight form can represent the pattern. Both imply
`+Str`. Generated YSD uses the canonical `=~"pattern"` spelling.

Canonical YSC stores both forms as `.like`, containing the exact JSON Schema
pattern. A match is bookended with `^` and `$`; a find is stored unchanged:

```yaml
whole:
  .type: +Str
  .like: ^pattern$
search:
  .type: +Str
  .like: pattern
```

`.like` is accepted only in `.ysc.yaml` and `.ysc.json`. Conversely, `.match`
and `.find` are YSD directives and are rejected in YSC input.

Compact enums require an explicit type reference and comma-separated members:

```yaml
mode: +Str [debug,info,error]
level: +Int [1,2,3]
logLevel: +Str [debug,=info,warning,error,fatal]
```

Members may contain letters, digits, whitespace, `.`, `-`, `_`, and `+`.
Whitespace around each comma-separated member is trimmed; whitespace inside a
member is preserved. Thus `[foo,bar,foo bar]` and
`[ foo, bar, foo bar ]` have the same meaning. Quotes are not supported inside
compact enums; use explicit `.enum` with a YAML sequence for quoted or other
punctuated values. The base controls scalar parsing, so `+Str [true,1]`
contains two strings. Prefix one member with `=` to also set `.init` to that
value. At most one member may be marked.

`+Str ==User` becomes `.const: User`, the exact-value constraint corresponding
to JSON Schema `const`. `+Str =="foo bar"` is the quoted form, and
`const:User` is the labeled alternative. A bare literal remains an accepted
inferred-type shorthand. It also means a constant, while `=value` means only a
default.


## Lists and Sizes

List suffixes are part of the value-side type expression:

```yaml
names?: +Str[1+]
```

This expands to `.type: +Str[]` and `.size: [1]`. The `[]` is part of the
list type; `.size` carries its bounds. Key-side list suffixes are rejected.

| Suffix | Meaning |
| --- | --- |
| `[]` | List with no size constraint |
| `[n]` | Exactly `n` items |
| `[n-m]` | Between `n` and `m` items |
| `[n+]` | At least `n` items |
| `[!]` | Unique items |
| `[$]` | Scalar or list |
| `[n-m,$!]` | Scalar or a unique list with the given size |

List properties may be comma-separated, whitespace-separated, or adjacent.
For example, `[1-10,$!]`, `[1-10,$,!]`, `[1-10 $ !]`, and `[1-10$!]` are
equivalent. Generated DSL uses the canonical `[size,$!]` order. `[+]` is an
input alias for `[1+]`. The former `|` separator is rejected. Multiple sizes
or repeated `$` and `!` flags are errors.

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

Canonical ranges use the same structural convention, with `null` for a
missing lower bound:

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
- Labeled scalar clauses may occur in any order. They are `type`, `match`,
  `find`, `const`, `range`, `size`, `list`, `item`, `solo`, `uniq`,
  `null`, `init`, `title`, `desc`, and scalar `also`.
- `enum:[...]` is the compact enum form. Structural `.one`, `.any`, `.all`,
  `.not`, `.with`, and `.when` values remain explicit.

Two exact triplets protect text that YAML forbids in a plain scalar: `:\ `
represents colon-space, and ` \#` represents space-hash. No other backslash
sequence is special, so `foo\ bar`, `\n`, and `\t` remain literal. A body
cannot contain a double quote. Use the explicit directive when that is needed.
A scalar consisting entirely of a YAML-quoted string is a literal value, not
an annotation, because YAML does not preserve its original quote style. The
obsolete trailing single-quoted description form is an error.


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

Directive order is insignificant. Expansion normalizes `.size` and emits a
stable directive order. A directive supplied by both the `.type` expression
and a sibling is an error, even when the values agree.


## Combinators

Reference-only alternatives have compact forms:

```yaml
one: +One[+Str,+Int]
any: +Any[+foo,+bar]
all: +All[+foo,+bar]
neither: +Not[+foo,+bar]
values: +Any[+foo,+bar][]
```

`One`, `Any`, and `All` require at least two references. `Not` requires at
least one; multiple references mean the value must match none of them. A list
suffix follows the complete combinator type.

Multiple references without brackets are an implicit conjunction. The first
is the base and the rest are additional constraint groups:

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


## Canonical Expansion

Compile human-authored YAML to canonical JSON with:

```sh
ysc -t yscj contact.ysd.yaml
ysc -t yscj -C contact.ysd.yaml
ysc -t yscj values.schema.json
```

Use `yscy` instead of `yscj` for canonical YAML. Use `-f/--from ysd`, `yscj`,
`yscy`, or `jsc` when a filename or stdin does not make the source format
clear. File suffixes `.ysd.yaml`, `.ysc.json`, `.ysc.yaml`, and `.schema.json`
are inferred automatically.

Canonical directives are emitted in this order:

```text
.type .item .one .any .all .not .like
.enum .const .range .size .solo .uniq .null .init .title
.desc .also .with .when
```

An unrefined built-in or named reference is emitted directly as a `+Type`
scalar. This is the compact form of a mapping whose only pair would be
`.type: +Type`. When annotations, validation constraints, or shape entries
share the mapping, the reference or complete tight expression remains under
`.type`.

List types append `[]` to the reference. An unconstrained list is therefore
emitted as a scalar such as `+Any[]`; constrained lists use forms such as
`.type: +Str[]` with `.size` or `.uniq`. `.list` is currently rejected and
reserved for a possible future list-constraint model; it does not mean
"convert this type into a list."

Unknown directives are errors. `.need` is reserved while requiredness is
represented by the property key. `.also`, `.with`, and `.when` may be retained
in explicit yamlschema, but an export that cannot represent one fails rather
than silently discarding it. `.pick` and the former `.oneof`, `.anyof`, and
`.allof` names are rejected with guidance to use `.one`, `.any`, and `.all`.

The former names `.titl`, `.just`, `.only`, `.mini`, and `.maxi` are rejected
with replacement diagnostics. Their replacements are `.title`, `.const`, and
`.range`.
