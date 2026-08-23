# yamlschema

`yamlschema` is an experimental schema language for YAML data.

The goal is to make schemas look like the data they describe while keeping
common validation constraints short and readable.
It is intended to cover the same kind of data-model validation as JSON Schema,
but with YAML-native syntax and a succinct form for human-authored schemas.

For the authoring syntax, see [doc/dsl.md](doc/dsl.md).
For the broader language design, see [doc/design.md](doc/design.md).
The [built-in type reference](doc/dsl.md#built-in-types) covers scalar, null,
arbitrary-value, and mapping types.

## Example

```yaml
+email: +Str =~"\S+@\S+"
+port: +Int 1..65535

name: +Str
email?: +email
port: +port
tags: +Str[1+,!]
address:
  street: +Str
  city: +Str
  zip: +Str =~"\d{5}(-\d{4})?"
```

This schema describes a mapping where:

- `name`, `port`, `tags`, and `address` are required.
- `email` is optional because the key ends in `?`.
- `tags` is a unique list with one or more string values.
- `+email` and `+port` are reusable definitions.
- Regexes, ranges, enums, list suffixes, and symbols express common
  constraints without verbose directive mappings.

## Repository Contents

- [bin/ysd](bin/ysd) converts among succinct yamlschema, expanded yamlschema,
  and JSON Schema.
- [test/](test/) contains YAMLScript TAP tests for the converter.
- [doc/design.md](doc/design.md) describes the language model, syntax,
  directives, JSON Schema mapping, and current implementation scope.
- [doc/dsl.md](doc/dsl.md) is the normative succinct and explicit DSL
  reference.
- [doc/json-schema.md](doc/json-schema.md) describes roundtripping with JSON
  Schema and the `.schema.json` convention.
- [note/yaml-schema-language-plan.md](note/yaml-schema-language-plan.md) is
  the original design note.

## File Extensions

yamlschema uses these file extensions:

- `.ysd.yaml` is the human-maintained yamlschema DSL form.
- `.ysdc.yaml` is the YSD Canonical form serialized as YAML.
- `.ysdc.json` is the YSD Canonical form serialized as JSON.
- `.schema.json` is the JSON Schema export or import form.

The optional top-level `.ysid` identifies the human-maintained YSD document.
Its suffix is `.ysd.yaml` in YSD and both YSDC serializations.
The corresponding JSON Schema `$id` uses `.schema.json`.
The converter replaces a recognized representation suffix and appends the
target suffix when none is present.

Typical flow:

```text
contact.ysd.yaml -> contact.ysdc.yaml or contact.ysdc.json
contact.ysd.yaml -> contact.schema.json
```

The format targets and explicit `--from` values are:

- `ysd` / `ysd.yaml` for succinct DSL YAML.
- `ysdc` / `ysdc.yaml` for canonical YAML.
- `ysdc.json` for canonical JSON.
- `jsc` / `schema.json` for JSON Schema.

## Installation

Prebuilt releases are available for Linux Intel, macOS ARM, Windows Intel,
and JavaScript WebAssembly.
The native archives contain `ysc` or `ysc.exe` and this ReadMe.
The `js_wasm` archive contains the raw `ysc.wasm` module for use with the Go
JavaScript WebAssembly runtime.

For local development, source the repo `.rc` file to put `bin/` on your
`PATH`:

```sh
. ./.rc
```

After that, the converter can be run as `ysd`:

```sh
ysd contact.schema.json
ysd contact.ysd.yaml
ysd -t ysd contact.schema.json
ysd -t ysdc.json contact.ysd.yaml
ysd -t ysdc contact.ysd.yaml
ysd -t jsc contact.ysd.yaml
ysd -t jsc -C contact.ysd.yaml
ysd -N contact.ysd.yaml
ysd -N legacy.schema.json
ysd -R contact.schema.json
ysd -R contact.ysd.yaml
```

## Converter Usage

The current converter script is `ysd`.
With no action option, it converts JSON Schema to YSD and yamlschema to JSON
Schema on standard output.
Input defaults to stdin.
Use `-` explicitly to read JSON Schema or yamlschema from stdin.
Supply `-f` / `--from` when stdin does not make the input format unambiguous:

```sh
ysd -t ysd - < contact.schema.json
ysd -t jsc - < contact.ysd.yaml
ysd -f ysd -NC - < contact.ysd.yaml
```

or from a file path:

```sh
ysd contact.schema.json
ysd contact.ysd.yaml
ysd -t ysd contact.schema.json
ysd -t jsc contact.ysd.yaml
```

For `-R`, an explicit `-f` takes precedence.
Without `-f`, input whose first non-whitespace character is `{` is treated as
JSON Schema; all other input is treated as YSD.
For YSD input, `-R` compares the expanded YSDC from `ysd -> ysdc` with the
expanded YSDC from `ysd -> jsc -> ysdc`.
The reported diff is therefore a YSDC diff.
For JSON Schema input, `-R` continues to compare normalized JSON Schema.

CLI information:

```sh
ysd --help
ysd --version
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

Expected `.ysd.yaml` output:

```yaml
# Converted from JSON Schema
.open: true
name: +Str
email?: +Str =~"\S+@\S+"
tags: +Str[1+,!]
```

## Development

The test suite is made of executable `.t` files under `test/`:

```sh
make test
```

The converter supports the direct mappings listed in
[doc/json-schema.md](doc/json-schema.md), including `oneOf`, `anyOf`, `allOf`,
and `not`.
Unsupported JSON Schema keywords are retained as same-named dotted directives,
such as `.if`, and reported with a warning so conversion does not silently
discard them.
