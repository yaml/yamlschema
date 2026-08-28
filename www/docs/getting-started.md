---
empty_sidebar: true
---

# Getting Started

YAMLSchema is a YAML-native schema language.
The schema follows the shape of the data, required fields are the default, and
constraints stay beside the values they describe.

## Write your first schema

Create `person.ysd.yaml`:

```yaml
name: +Str
age?: +Int 0..120
email?: +JSON-Schema/email
tags?: +Str[] [=good, bad, ugly]
```

This schema requires `name`.
The other fields are optional because their keys end in `?`.
Age must be an integer from 0 through 120, and email uses the JSON Schema
email format.
Tags are strings chosen from `good`, `bad`, and `ugly`, with `good` as the
default.

!!! tip "Try it without installing anything"

    Open the [interactive editor](demo/person.md),
    change either pane, and watch the other representation update.

## Install the command

With Bash or Zsh:

```bash
source <(curl -sL yamlschema.org/install)
```

With Fish:

```fish
curl -sL yamlschema.org/install | source -
```

With PowerShell:

```powershell
irm https://yamlschema.org/install.ps1 | iex
```

On Bash, Zsh, and Fish, running the sourced command adds `ysd` to the
current shell's `PATH` and
immediately enables tab completion and the YAMLSchema man pages.
Try `ysd --<TAB>` or `man ysd` after it finishes.
The installer also clones the matching release tag into
`$HOME/.local/share/yamlschema/` and prints the `.rc` line to add for future
shells.
Root installations default to `/usr/local`.

The PowerShell installer selects the AMD64 or ARM64 Windows release, installs
`ysd.exe` under `$HOME\.local\bin`, and adds that directory to the current
shell and the user `PATH`.
It enables tab completion in the current shell and adds the completion script
to `$PROFILE.CurrentUserAllHosts` for future PowerShell sessions.
Native Windows man pages are not available, so use `ysd --help` instead.

Choose another prefix or release by passing Make variables after the sourced
command:

=== "Bash and Zsh"

    ```bash
    source <(curl -sL yamlschema.org/install) \
      PREFIX=/opt/yamlschema VERSION=0.1.3
    ```

=== "Fish"

    ```fish
    curl -sL yamlschema.org/install | \
      source - PREFIX=/opt/yamlschema VERSION=0.1.3
    ```

The Bash, Zsh, and Fish installer requires Git, curl, GNU Make 3.81 or newer,
and `tar` or `unzip`.

To clone, build, and install from source instead:

```bash
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

## Convert JSON Schema to .ysd

The default conversion also works in the other direction:

```bash
ysd person.schema.json
```

To save the compact .ysd form:

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
