---
title: YAMLSchema Cheat Sheet
description: Compact YAMLSchema syntax reference
empty_sidebar: true
hide:
- toc
---

# YAMLSchema Cheat Sheet

<p class="cheat-intro">
  The compact forms used most often when writing <code>.ysd.yaml</code> files.
</p>

<div class="cheat-grid" markdown>

<section class="cheat-card" markdown>

## Fields

```yaml
name: +Str       # required
email?: +Str     # optional
```

The key mirrors the data key.
Add `?` only when the field is optional.

</section>

<section class="cheat-card" markdown>

## Built-in types

```yaml
anything: +Any
text: +Str
count: +Int
number: +Num
float: +Float
enabled: +Bool
nothing: +Null
```

</section>

<section class="cheat-card" markdown>

## JSON Schema formats

```yaml
birthday: +JSONSchema/date
created: +JSONSchema/date-time
email: +JSONSchema/email
host: +JSONSchema/hostname
id: +JSONSchema/uuid
```

</section>

<section class="cheat-card" markdown>

## Numeric ranges

```yaml
port: +Int 1..65535
zero_or_more: +Int 0..
percentage: +Num 0..100
upper_bound?: +Num ..10
```

</section>

<section class="cheat-card" markdown>

## Strings and patterns

```yaml
code: +Str 3..12
whole: +Str =~"[A-Z]+"
contains: +Str /[0-9]+/
```

`=~` matches the complete string.
`/.../` searches within it.

</section>

<section class="cheat-card" markdown>

## Constants and enums

```yaml
kind: +Str ==person
role: +Str [admin, user, guest]
answer: [true, false, 42]
```

</section>

<section class="cheat-card" markdown>

## Lists

```yaml
names: +Str[]
tags: +Str[1+]
pair: +Int[2]
unique: +Str[!,1+]
maybe_one: +Str[$]
```

</section>

<section class="cheat-card" markdown>

## Mapping shapes

```yaml
person:
  name: +Str
  age?: +Int 0..

labels: +Map{+Str}
metadata: +Map{+Any}
```

Shaped mappings are closed by default.

</section>

<section class="cheat-card" markdown>

## Open mappings

```yaml
.open: true

closed:
  .open: false
  fixed: +Str

typed:
  fixed?: +Str
  +Str: +Int
```

</section>

<section class="cheat-card" markdown>

## Definitions

```yaml
+email: +JSONSchema/email
+address:
  street: +Str
  city: +Str

contact: +email
home: +address
```

</section>

<section class="cheat-card" markdown>

## References

```yaml
local: +address
external: +Ref(profile.schema.json)

detailed:
  .xref: https://example.com/profile.schema.json
  .desc: External profile
```

</section>

<section class="cheat-card" markdown>

## Nullability

```yaml
maybe_text: +Str~
maybe_list: +Str[]~
optional_nullable?: +Int~
```

`?` controls presence.
`~` permits a null value.

</section>

<section class="cheat-card" markdown>

## Dependencies

```yaml
postOfficeBox?: +Str :need(streetAddress)
streetAddress?: +Str
```

If `postOfficeBox` is present, `streetAddress` must also be present.

</section>

<section class="cheat-card" markdown>

## Combinators

```yaml
value: +One(+Str,+Int)
choice: +Any(+Str,+Bool)

.one:
- kind?: +Str ==person
- kind?: +Str ==company
```

</section>

<section class="cheat-card" markdown>

## Annotations

```yaml
.title: Person
.desc: A person record

name: +Str "Display name"
age:
  .type: +Int
  .desc: Age in years
```

</section>

<section class="cheat-card" markdown>

## File forms

```text
contact.ysd.yaml
contact.ysdc.yaml
contact.ysdc.json
contact.schema.json
```

.ysd is authored.
.ysdc is canonical.
JSON Schema is interchange.

</section>

</div>

<p class="cheat-footer">
  See the <a href="../reference/dsl/">complete language reference</a> for
  expansion rules and less common explicit directives.
</p>
