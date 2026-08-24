# Examples

These examples show the compact YSD form.
Each link opens the complete packaged example in the interactive editor.

## Required and optional fields

```yaml
name: +Str
age?: +Int 0..120
email?: +JSONSchema/email
tags?: +Str[] [=good, bad, ugly]
```

`name` is required.
The optional fields demonstrate a JSON Schema format, an integer range, and a
list whose items come from a fixed set.

[Open Person in the editor](demo/person.md){ .md-button }

## Dependent fields

```yaml
postOfficeBox?: +Str :need(streetAddress)
extendedAddress?: +Str :need(streetAddress)
streetAddress?: +Str
locality: +Str
region: +Str
postalCode?: +Str
countryName: +Str
```

When either extended address field is present, `streetAddress` is required.
The relationship maps to JSON Schema `dependentRequired`.

[Open Address in the editor](demo/address.md){ .md-button }

## Alternatives and external references

```yaml
deviceType: +Str
.one:
- .xref: https://example.com/smartphone.schema.json
  deviceType?: +Str ==smartphone
- .xref: https://example.com/laptop.schema.json
  deviceType?: +Str ==laptop
```

Exactly one branch must match.
Each branch combines a discriminating constant with an external schema
reference.

[Open Device Type in the editor](demo/device-type.md){ .md-button }

## Named definitions

```yaml
+address:
  street: +Str
  city: +Str

billing: +address
shipping?: +address
```

Definitions begin with `+` and can be referenced anywhere in the document.

## Lists and maps

```yaml
tags?: +Str[1+,!]
labels?: +Map{+Str}
metadata?: +Map{+Any}
```

`tags` is a non-empty list of unique strings.
The two map forms accept arbitrary string keys with string or unrestricted
values.

## Real-world schema

The Harbor Next Helm chart example demonstrates nested definitions, maps,
lists, ranges, annotations, and open subtrees in a production-sized schema.

[Open Harbor Next in the editor](demo/harbor-next.md){ .md-button }
