# ysd -- Convert YAMLSchema and JSON Schema

`ysd` converts between YSD, YSD Canonical, and JSON Schema.
It reads standard input when no input path is given and writes to standard
output unless `-o` names a file.

## Usage

```text
ysd [INPUT]
ysd (-t FORMAT | -o FILE) [INPUT]
ysd -N, --norm [INPUT]
ysd -R, --roundtrip [-q, --quiet] [INPUT]
```

## Options

| Option | Meaning |
| --- | --- |
| `-t`, `--to FORMAT` | Select `ysd`, `ysdc`, `ysdc.yaml`, `ysdc.json`, or `jsc` |
| `-f`, `--from FORMAT` | Override the detected input format |
| `-o`, `--output FILE` | Write to a file, or use `-` for standard output |
| `-N`, `--norm` | Normalize to draft 2020-12 JSON Schema |
| `-R`, `--roundtrip` | Test a JSON Schema or YSD roundtrip |
| `-q`, `--quiet` | Suppress successful roundtrip output |
| `-C`, `--compact` | Emit compact JSON |
| `--complete=SHELL` | Generate completion for Bash, Zsh, or Fish |
| `--help` | Show command help |
| `--version` | Show the installed version |

## Shell completion

The sourced installer enables completion automatically in Bash, Zsh, and
Fish.
Completion scripts can also be generated directly:

```bash
ysd --complete=bash
ysd --complete=zsh
ysd --complete=fish
```

The installed `.rc` also adds the bundled manuals to `MANPATH`.
Use `man ysd`, `man yamlschema`, `man yamlschema-design`, or
`man yamlschema-json-schema`.

## Default direction

The first non-whitespace character and the filename extension determine the
input form.
JSON input converts to YSD, while YSD and YSDC input convert to JSON Schema.

```bash
ysd contact.schema.json
ysd contact.ysd.yaml
ysd contact.ysdc.yaml
ysd contact.ysdc.json
```

Use `-f` when reading standard input or when a filename is ambiguous:

```bash
cat contact.yaml | ysd -f ysd -t jsc
```

## Explicit targets

```bash
ysd -t ysd contact.schema.json
ysd -t ysdc.yaml contact.ysd.yaml
ysd -t ysdc.json contact.ysd.yaml
ysd -t jsc contact.ysd.yaml
```

## Normalize JSON Schema

Normalization adds the draft 2020-12 dialect, chooses canonical keyword
positions, and preserves property order.

```bash
ysd -N contact.schema.json
```

## Roundtrip reports

Roundtrip checks begin from the input representation:

```bash
ysd -R contact.schema.json
ysd -R contact.ysd.yaml
```

Use quiet mode in automation:

```bash
ysd -Rq contact.ysd.yaml
```

A successful quiet check produces no output and exits successfully.
