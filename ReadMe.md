# YAMLSchema

`YAMLSchema` is an experimental schema language for YAML data.

The goal is to make schemas look like the data they describe while keeping
common validation constraints short and readable.
It is intended to cover the same kind of data-model validation as JSON Schema,
using a succinct form designed for human-authored schemas.

For the authoring syntax, see [doc/dsl.md](doc/dsl.md).
For the broader language design, see [doc/design.md](doc/design.md).
The [built-in type reference](doc/dsl.md#built-in-types) covers scalar, null,
arbitrary-value, and mapping types.

## Example

```yaml
+email: +Str ~"\S+@\S+"
+port: +Int 1..65535

name: +Str
email?: +email
port: +port
tags: +Str[1+,!]
address:
  street: +Str
  city: +Str
  zip: +Str ~"{digit}{5}(-{digit}{4})?"
```

This schema describes a mapping where:

- `name`, `port`, `tags`, and `address` are required.
- `email` is optional because the key ends in `?`.
- `tags` is a unique list with one or more string values.
- `+email` and `+port` are reusable definitions.
- Regexes, ranges, enums, list suffixes, and symbols express common
  constraints without verbose directive mappings.

## Repository Contents

- [bin/ysd](bin/ysd) runs the converter during development.
- [lib/ysd/](lib/ysd/) contains the converter core and native library
  entrypoints.
- [python/](python/) contains the Python binding and wheel packaging.
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

YAMLSchema uses these file extensions:

- `.ysd.yaml` and `.ysd.json` contain the human-maintained `.ysd` form.
- `.ysdc.yaml` and `.ysdc.json` contain the canonical `.ysdc` form.
- `.schema.json`, `.schema.json.yaml`, `.schema.yaml`, and `.schema.yml`
  contain JSON Schema.

JSON Schema input may use JSON or YAML syntax regardless of its filename
extension, including YAML content stored in a `.schema.json` file.

The optional top-level `.ysid` identifies the human-maintained .ysd document.
Its suffix is `.ysd.yaml` in .ysd and both .ysdc serializations.
The corresponding JSON Schema `$id` uses `.schema.json`.
The converter replaces a recognized representation suffix and appends the
target suffix when none is present.

Typical flow:

```text
contact.ysd.yaml -> contact.ysdc.yaml or contact.ysdc.json
contact.ysd.yaml -> contact.schema.json
```

The `--to` targets and explicit `--from` values are `ysd`, `ysdc`, and `jsc`.
The `.ysd` and `.ysdc` targets emit YAML by default, while `jsc` emits JSON.
Use `-Y` / `--yaml` or `-J` / `--json` to select a serialization explicitly.
The output options and a recognized output filename extension must agree.

## Installation

Install the current release with Bash or Zsh:

```sh
source <(curl -sL yamlschema.org/install)
```

For Fish:

```fish
curl -sL yamlschema.org/install | source -
```

The installer puts `ysd` in `$HOME/.local/bin` for a normal user and in
`/usr/local/bin` for root.
Running the sourced command adds that directory to the current shell's `PATH`
and immediately enables tab completion and the YAMLSchema man pages.
The installer clones the matching release tag into
`$PREFIX/share/yamlschema/` and prints the `.rc` line to add for future shells.
Set `PREFIX` or `VERSION` after the sourced installer command to override the
defaults:

```sh
source <(curl -sL yamlschema.org/install) \
  PREFIX=/opt/yamlschema VERSION=0.1.3
```

```fish
curl -sL yamlschema.org/install | \
  source - PREFIX=/opt/yamlschema VERSION=0.1.3
```

The installer requires Git, curl, GNU Make 3.81 or newer, and `tar` or
`unzip` for the platform archive.
Prebuilt releases are available for Linux Intel and ARM64, macOS ARM64,
Windows Intel and ARM64, and JavaScript WebAssembly.
The native archives contain `ysd` or `ysd.exe` and this ReadMe.
The `js_wasm` archive contains the raw `ysd.wasm` module for use with the Go
JavaScript WebAssembly runtime.

To clone, build, and install from source:

```sh
git clone https://github.com/yaml/yamlschema
cd yamlschema
make install PREFIX=$HOME/.local
```

This installs the built command under `$PREFIX/bin` and clones the current
committed `HEAD` into `$PREFIX/share/yamlschema`.
The target refuses to replace a checkout that has local changes.
It prints the `.rc` line to add to your shell configuration.
Run `ysd --upgrade` to fetch the installed checkout's configured default
branch and rebuild from its current `HEAD`.

For local development, source the repo `.rc` file to put `bin/` on your
`PATH`, enable tab completion, and expose the man pages:

```sh
. ./.rc
```

The shell-specific completion files are `share/complete.bash`,
`share/complete.zsh`, and `share/complete.fish`.

After installation or local setup, try `ysd --<TAB>` or `man ysd`.

### Python

Install the Python binding from PyPI:

```sh
python -m pip install ysd
```

The wheel includes the native `libysd` library for its platform:

```python
from ysd import YAMLSchema

ysd = YAMLSchema()
source = ysd.json_schema_to_ysd({
    "type": "object",
    "properties": {"name": {"type": "string"}},
})
schema = ysd.ysd_to_json_schema(source)
```

The binding requires Python 3.10 or newer.
It performs conversion rather than instance validation.
The returned schemas can be passed directly to the Python `jsonschema`
package when validation is needed.

After that, the converter can be run as `ysd`:

```sh
ysd contact.schema.json
ysd contact.ysd.yaml
ysd -t ysd contact.schema.json
ysd -t ysdc -J contact.ysd.yaml
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
With no action option, it converts JSON Schema to .ysd and YAMLSchema to JSON
Schema on standard output.
Input defaults to stdin.
Use `-` explicitly to read JSON Schema or YAMLSchema from stdin.
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
JSON Schema; all other input is treated as .ysd.
For .ysd input, `-R` compares the expanded .ysdc from `ysd -> ysdc` with the
expanded .ysdc from `ysd -> jsc -> ysdc`.
The reported diff is therefore a .ysdc diff.
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
email?: +Str ~"\S+@\S+"
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
