# Getting Started

YAMLSchema is a YAML-native schema language.
The schema follows the shape of the data, required fields are the default, and
constraints stay beside the values they describe.

## Write your first schema

Create `person.ysd.yaml`:

```yaml
.title: Person
name: +Str
age?: +Int 0..
email?: +JSONSchema/email
```

This schema requires `name`.
The other fields are optional because their keys end in `?`.
Age must be a non-negative integer, and email uses the JSON Schema email
format.

!!! tip "Try it without installing anything"

    Open the [interactive editor](editor.md?source=ysd&example=person),
    change either pane, and watch the other representation update.

## Convert to JSON Schema

The `ysd` command infers the output from the input filename:

```bash
ysd person.ysd.yaml
```

It writes JSON Schema to standard output.
To choose an output file:

```bash
ysd person.ysd.yaml -o person.schema.json
```

The generated schema uses JSON Schema draft 2020-12.

## Convert JSON Schema to YSD

The default conversion also works in the other direction:

```bash
ysd person.schema.json
```

To save the compact YSD form:

```bash
ysd person.schema.json -o person.ysd.yaml
```

## Check a roundtrip

Use `-R` to convert through the opposite representation and compare the
normalized result:

```bash
ysd -R person.ysd.yaml
ysd -R person.schema.json
```

`OK` means the supported constraints survived the roundtrip.
When they do not, `ysd` prints a unified diff showing the normalized change.

## Choose the right form

| Extension | Purpose |
| --- | --- |
| `.ysd.yaml` | Compact source written and reviewed by people |
| `.ysdc.yaml` | Canonical YAMLSchema serialized as YAML |
| `.ysdc.json` | Canonical YAMLSchema serialized as JSON |
| `.schema.json` | JSON Schema interchange |

Continue with the [examples](examples.md), keep the
[cheat sheet](cheat-sheet.md) nearby, or read the complete
[language reference](reference/dsl.md).
