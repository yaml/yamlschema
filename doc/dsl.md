yamlschema DSL
==============

This page specifies the human-authored yamlschema DSL and its expansion to
canonical `.ysc.json`. A schema defines types: sets of constraints for a
scalar, mapping, or list of another type.


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
  requests?: +Map
  limits?: +Map

resources?: +resources
```

Anonymous mapping shapes infer `.base: +Map`. Shaped mappings are closed;
`+Str*` admits otherwise unmatched string keys:

```yaml
labels:
  fixed?: +Str
  +Str*: +Str
```


## Tight Type Expressions

A tight type expression is a YAML plain scalar. Its clauses have one order:

```text
core [list] [null] [pattern-or-range] [enum] [size]
     [default] [title] [description]
```

The core is a `+Type` reference, regex, numeric range, pipe enum, or literal.
A leading reference may be refined:

```yaml
foo: +Str /a.*b/
port: +Int 1..65535
mode: +Str debug|info|error
```

These expand to explicit directives. Inferred bases are always materialized:

```yaml
foo:
  .base: +Str
  .like: a.*b
port:
  .base: +Int
  .mini: 1
  .maxi: 65535
mode:
  .base: +Str
  .enum: [debug, info, error]
```

Regex delimiters are removed in canonical form. Pipe members are parsed as
YAML scalars and must have a common type. `1|2` infers `+Int`; `+Str 1|2`
forces string members. A literal becomes its inferred base plus `.only`.


## Lists and Sizes

List suffixes may be on either side:

```yaml
names?[1+]: +Str
names?: +Str[1+]
```

Both expand to `.list: true`, `.base: +Str`, and `.size: [1]`. Do not put a
list suffix on both sides of one entry.

| Suffix | Meaning |
| --- | --- |
| `[]` | List with no size constraint |
| `[n]` | Exactly `n` items |
| `[n-m]` | Between `n` and `m` items |
| `[n+]` | At least `n` items |
| `[!...]` | Unique items |
| `[$]` | Scalar or list |
| `[$|n-m]` | Scalar or a list with the given size |

`[+]` is accepted as an input alias for `[1+]`; generated DSL uses `[1+]`.
An optional key-side list is written `foo?[...]`.

A size clause also works after string, list, or mapping constraints:

```yaml
code: +Str 8
names: +Str[] 1+
labels: +Map 1-20
```

Canonical sizes contain one number for an open upper bound and two for a
bounded or exact size:

```text
1+    -> [1]
10    -> [10, 10]
10-20 -> [10, 20]
```

The old `"*"` bound is invalid.


## Nulls and Annotations

Nullability is a value-side suffix:

```yaml
enabled?: +Bool~
```

Tight annotations follow all constraints:

```yaml
enabled?: +Bool~ =false titl:"Enabled" "Enable the service"
label?: +Str ="pretty good"
```

- `=value` is a single YAML scalar default.
- `="..."` is a string default that may contain spaces.
- `titl:"..."` is `.titl`.
- A final `"..."` is `.desc`.

The double-quoted bodies have no escapes and cannot contain a double quote.
Use the explicit directive when that is needed. A scalar consisting entirely
of a YAML-quoted string is a literal value, not an annotation, because YAML
does not preserve its original quote style. The obsolete trailing
single-quoted description form is an error.


## Hybrid Explicit Types

When one constraint is clearer explicitly, `.base` may contain the complete
tight expression and sibling directives add the exceptional parts:

```yaml
foo:
  .base: +Str[] /a.*b/ 10-20
  .titl: The "Good" Parts
```

This is equivalent to:

```yaml
foo:
  .base: +Str
  .list: true
  .like: a.*b
  .size: 10-20
  .titl: The "Good" Parts
```

Directive order is insignificant. Expansion normalizes `.size` and emits a
stable directive order. A directive supplied by both the `.base` expression
and a sibling is an error, even when the values agree.


## Canonical Expansion

Compile human-authored YAML to canonical JSON with:

```sh
ysc -t yscj contact.ysc.yaml
ysc -t yscj -C contact.ysc.yaml
ysc -t yscj values.schema.json
```

Use `-f/--from ysc`, `yscj`, or `jsc` when a filename or stdin does not make
the source format clear. File suffixes `.ysc.yaml`, `.ysc.json`, and
`.schema.json` are inferred automatically.

Canonical directives are emitted in this order:

```text
.base .list .item .like .enum .only .mini .maxi
.size .solo .uniq .null .init .titl .desc
```

Unknown directives are errors. `.need` is reserved while requiredness is
represented by the property key. `.also`, `.pick`, `.with`, and `.when` may
be retained in explicit yamlschema, but an export that cannot represent one
fails rather than silently discarding it.
