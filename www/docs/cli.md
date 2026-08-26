---
empty_sidebar: true
---

# ysd - Convert YAMLSchema and JSON Schema

`ysd` converts between `.ysd`, canonical `.ysdc`, and JSON Schema.
It reads standard input when no input path is given and writes to standard
output unless `-o` names a file.

See the
[installation instructions](https://yamlschema.org/getting-started/#install-the-command).

## Usage

```text
ysd --help
ysd [INPUT]
ysd (-t FORMAT | -o FILE) [INPUT]
ysd -N, --norm [INPUT]
ysd -R, --roundtrip [-q, --quiet] [INPUT]
```

## Options

| Option | Meaning |
| --- | --- |
| `-t`, `--to FORMAT` | Select `ysd`, `ysdc`, or `jsc` |
| `-f`, `--from FORMAT` | Select `ysd`, `ysdc`, or `jsc` input |
| `-Y`, `--yaml` | Emit YAML output |
| `-J`, `--json` | Emit JSON output |
| `-o`, `--output FILE` | Write to a file, or use `-` for standard output |
| `-N`, `--norm` | Normalize to draft 2020-12 JSON Schema |
| `-R`, `--roundtrip` | Test a JSON Schema or .ysd roundtrip |
| `-q`, `--quiet` | Suppress successful roundtrip output |
| `-C`, `--compact` | Emit compact JSON |
| `--upgrade` | Upgrade from the repository's default branch |
| `--help` | Show command help |
| `--version` | Show the installed version |

## Shell completion

The installers enable completion automatically in Bash, Zsh, Fish, and
PowerShell by loading the matching script from the installation.
The scripts can also be sourced directly from a checkout or installation:

```bash
source /path/to/yamlschema/share/complete.bash
source /path/to/yamlschema/share/complete.zsh
```

```fish
source /path/to/yamlschema/share/complete.fish
```

```powershell
. $HOME\.local\share\yamlschema\complete.ps1
```

The installed `.rc` also adds the bundled manuals to `MANPATH`.
Use `man ysd`, `man yamlschema`, `man yamlschema-design`, or
`man yamlschema-json-schema`.

## Upgrade

`ysd --upgrade` fetches the configured default branch of the repository under
`$PREFIX/share/yamlschema`, checks out its current `HEAD`, and runs
`make install` with the same prefix.
The command refuses to replace an installed checkout with local changes.

## Default direction

The first non-whitespace character and the filename extension determine the
input form.
JSON input converts to .ysd, while .ysd and .ysdc input convert to JSON Schema.

The recognized filename extensions are `.ysd.yaml`, `.ysd.json`,
`.ysdc.yaml`, `.ysdc.json`, `.schema.json`, `.schema.json.yaml`,
`.schema.yaml`, and `.schema.yml`.

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

The `.ysd` and `.ysdc` targets emit YAML by default, while `jsc` emits JSON.
Use `-Y` / `--yaml` or `-J` / `--json` to override that default.
The output options and a recognized output filename extension must agree.

```bash
ysd -t ysd contact.schema.json
ysd -t ysdc contact.ysd.yaml
ysd -t ysdc -J contact.ysd.yaml
ysd -t jsc contact.ysd.yaml
ysd -t jsc -Y contact.ysd.yaml
```

## Normalize JSON Schema

Normalization adds the draft 2020-12 dialect, chooses canonical keyword
positions, and preserves property order.

```bash
ysd -N contact.schema.json
ysd -N -Y contact.schema.json
```

`-C` / `--compact` applies only to JSON output.

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
