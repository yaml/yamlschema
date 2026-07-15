# yamlschema

`yamlschema` is an experimental schema language for YAML data.

The goal is to make schemas look like the data they describe while keeping
common validation constraints short and readable. It is intended to cover the
same kind of data-model validation as JSON Schema, but with YAML-native syntax
and a succinct form for human-authored schemas.

For the full language design, see [doc/design.md](doc/design.md).

## Example

```yaml
+email: /^\S+@\S+$/
+port: 1..65535

name: +Str
email?: +email
port: +port
tags[!+]: +Str
address:
  street: +Str
  city: +Str
  zip: /^\d{5}(-\d{4})?$/
```

This schema describes a mapping where:

- `name`, `port`, `tags`, and `address` are required.
- `email` is optional because the key ends in `?`.
- `tags[!+]` is a unique list with one or more string values.
- `+email` and `+port` are reusable definitions.
- Regexes, ranges, enums, list suffixes, and symbols imply most explicit type
  information.

## Repository Contents

- [bin/ysc](bin/ysc) converts a JSON Schema document to the current
  yamlschema syntax.
- [test/](test/) contains YAMLScript TAP tests for the converter.
- [doc/design.md](doc/design.md) describes the language model, syntax,
  directives, JSON Schema mapping, and current implementation scope.
- [doc/json-schema.md](doc/json-schema.md) describes roundtripping with JSON
  Schema and the `.schema.json` convention.
- [note/yaml-schema-language-plan.md](note/yaml-schema-language-plan.md) is the
  original design note.

## File Extensions

yamlschema uses these file extensions:

- `.ysc.yaml` is the human-maintained yamlschema DSL form.
- `.ysc.json` is the compiled, expanded yamlschema form.
- `.schema.json` is the JSON Schema export or import form.

Typical flow:

```text
contact.ysc.yaml -> contact.ysc.json -> contact.schema.json
```

## Installation

For local development, source the repo `.rc` file to put `bin/` on your `PATH`:

```sh
. ./.rc
```

After that, the converter can be run as `ysc`:

```sh
ysc -t ysc contact.schema.json
ysc -t jsc contact.ysc.yaml
ysc -t jsc -C contact.ysc.yaml
ysc -F contact.schema.json
ysc -N legacy.schema.json
```

## Converter Usage

The current converter script is `ysc`.
It requires either `-t` / `--to`, `-o` / `--output`, `-F` / `--fmt`, or
`-N` / `--norm`.
Input defaults to stdin.
Use `-` explicitly to read JSON Schema or yamlschema from stdin:

```sh
ysc -t ysc - < contact.schema.json
ysc -t jsc - < contact.ysc.yaml
ysc -FC - < contact.schema.json
```

or from a file path:

```sh
ysc -t ysc contact.schema.json
ysc -t jsc contact.ysc.yaml
```

CLI information:

```sh
ysc --help
ysc --version
```

Example input:

```json
{
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

Expected `.ysc.yaml` output:

```yaml
name: +Str
email?: /^\S+@\S+$/
tags[!+]: +Str
```

## Development

The test suite is made of executable `.t` files under `test/`:

```sh
make test
```

The converter currently targets the direct JSON Schema mappings listed in the
design document. More complex JSON Schema features such as `oneOf`, `allOf`,
conditionals, and `patternProperties` are still design work; when encountered,
the converter emits `# TODO: <keyword>` markers where possible.
