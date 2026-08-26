#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: no-args
  cmnd: bin/ysd
  want: |
    Usage: ysd [INPUT]
           ysd (-t FORMAT | -o FILE) [INPUT]
           ysd -N, --norm [INPUT]
           ysd -R, --roundtrip [-q, --quiet] [INPUT]

    Convert between JSON Schema and yamlschema formats.

    Arguments:
      INPUT                 Input schema path. Defaults to stdin.

    Options:
      -t, --to FORMAT       Output format: ysd, ysdc, or jsc.
                            Defaults based on input.
      -f, --from FORMAT     Input format: ysd, ysdc, or jsc.
      -Y, --yaml            Emit YAML output.
      -J, --json            Emit JSON output.
      -o, --output FILE     Write output to FILE. Use "-" for stdout.
      -N, --norm            Normalize input to draft 2020-12 JSON Schema.
      -R, --roundtrip       Check JSON Schema or .ysd roundtrip.
      -q, --quiet           Suppress roundtrip output.
      -C, --compact         Emit compact JSON output.
          --complete=SHELL  Generate completion for bash, zsh, or fish.
          --help            Show this help text.
          --version         Show version.

- name: help
  cmnd: bin/ysd --help
  want: |
    Usage: ysd [INPUT]
           ysd (-t FORMAT | -o FILE) [INPUT]
           ysd -N, --norm [INPUT]
           ysd -R, --roundtrip [-q, --quiet] [INPUT]

    Convert between JSON Schema and yamlschema formats.

    Arguments:
      INPUT                 Input schema path. Defaults to stdin.

    Options:
      -t, --to FORMAT       Output format: ysd, ysdc, or jsc.
                            Defaults based on input.
      -f, --from FORMAT     Input format: ysd, ysdc, or jsc.
      -Y, --yaml            Emit YAML output.
      -J, --json            Emit JSON output.
      -o, --output FILE     Write output to FILE. Use "-" for stdout.
      -N, --norm            Normalize input to draft 2020-12 JSON Schema.
      -R, --roundtrip       Check JSON Schema or .ysd roundtrip.
      -q, --quiet           Suppress roundtrip output.
      -C, --compact         Emit compact JSON output.
          --complete=SHELL  Generate completion for bash, zsh, or fish.
          --help            Show this help text.
          --version         Show version.

- name: version
  cmnd: |
    sh -c '
      bin/ysd --version |
        perl -pe "s/[0-9]+[.][0-9]+[.][0-9]+/VERSION/"
    '
  want: |
    ysd VERSION

- name: completion-syntax
  cmnd: |
    sh -c '
      for shell in bash zsh fish; do
        bin/ysd --complete="$shell" | "$shell" -n
        printf "%s ok\n" "$shell"
      done
    '
  want: |
    bash ok
    zsh ok
    fish ok

- name: completion-registration
  cmnd: |
    sh -c '
      bash --noprofile --norc -c \
        "source <(bin/ysd --complete=bash); declare -F _ysd >/dev/null" &&
        echo "bash registered"
      zsh -f -c \
        "export YAMLSCHEMA_ROOT=\$PWD; source <(bin/ysd --complete=zsh);
         whence -w _ysd | grep -q function" &&
        echo "zsh registered"
      fish --no-config -c \
        "bin/ysd --complete=fish | source;
         functions -q __fish_complete_ysd_inputs" &&
        echo "fish registered"
    '
  want: |
    bash registered
    zsh registered
    fish registered

- name: bash-completion-candidates
  cmnd: |
    bash --noprofile --norc -c '
      source <(bin/ysd --complete=bash)
      COMP_WORDS=(ysd --fr)
      COMP_CWORD=1
      _ysd
      [[ " ${COMPREPLY[*]} " == *" --from "* ]]
      COMP_WORDS=(ysd --from ys)
      COMP_CWORD=2
      _ysd
      [[ " ${COMPREPLY[*]} " == *" ysdc "* ]]
      [[ " ${COMPREPLY[*]} " != *" ysdc.json "* ]]
      COMP_WORDS=(ysd --ya)
      COMP_CWORD=1
      _ysd
      [[ " ${COMPREPLY[*]} " == *" --yaml "* ]]
      COMP_WORDS=(ysd --complete=f)
      COMP_CWORD=1
      _ysd
      [[ " ${COMPREPLY[*]} " == *" --complete=fish "* ]]
      dir=$(mktemp -d)
      trap "rm -r \"$dir\"" EXIT
      touch "$dir/person.ysd.yaml" "$dir/device.schema.yml" \
        "$dir/plain.txt"
      cd "$dir"
      COMP_WORDS=(ysd per)
      COMP_CWORD=1
      _ysd
      [[ " ${COMPREPLY[*]} " == *" person.ysd.yaml "* ]]
      [[ " ${COMPREPLY[*]} " != *" plain.txt "* ]]
      COMP_WORDS=(ysd dev)
      _ysd
      [[ " ${COMPREPLY[*]} " == *" device.schema.yml "* ]]
      echo ok
    '
  want: |
    ok

- name: completion-errors
  cmnd: |
    sh -c '
      bin/ysd --complete=tcsh 2>&1 |
        perl -ne "print if $. == 1"
      bin/ysd --complete 2>&1 |
        perl -ne "print if $. == 1"
    '
  want: |
    ysd: unknown shell for --complete: tcsh
    ysd: --complete requires bash, zsh, or fish

- name: old-command-is-removed
  cmnd: sh -c 'test ! -e bin/ysc && echo ok'
  want: |
    ok

- name: file-input-defaults-to-ysd
  cmnd: |
    sh -c '
      bin/ysd www/docs/assets/editor/examples/device-type.schema.json |
        perl -ne "print if $. <= 4"
    '
  want: |
    # Converted from JSON Schema
    .ysid: https://example.com/device.ysd.yaml
    .open: true
    deviceType: +Str

- name: yamlschema-files-default-to-json-schema
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      trap "rm -r \"$dir\"" EXIT
      printf "%s\n" "name: +Str" > "$dir/values.ysd.yaml"
      printf "%s\n" "name: +Str" > "$dir/values.ysdc.yaml"
      printf "%s\n" "{\"name\":\"+Str\"}" > "$dir/values.ysdc.json"
      for file in values.ysd.yaml values.ysdc.yaml values.ysdc.json; do
        bin/ysd "$dir/$file" |
          perl -pe \
            "s/YAMLSCHEMA v[0-9]+[.][0-9]+[.][0-9]+/YAMLSCHEMA vVERSION/" |
          perl -ne "print if $. <= 3"
      done
    '
  want: |
    {
      "$comment": "DO NOT EDIT. THIS FILE GENERATED BY YAMLSCHEMA vVERSION",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
    {
      "$comment": "DO NOT EDIT. THIS FILE GENERATED BY YAMLSCHEMA vVERSION",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
    {
      "$comment": "DO NOT EDIT. THIS FILE GENERATED BY YAMLSCHEMA vVERSION",
      "$schema": "https://json-schema.org/draft/2020-12/schema",

- name: reject-removed-format-options
  cmnd: |
    sh -c '
      bin/ysd -F 2>&1 | sed -n 1p
      bin/ysd --fmt 2>&1 | sed -n 1p
    '
  want: |
    ysd: unknown option -F
    ysd: unknown option --fmt

- name: reject-serialized-format-names
  cmnd: |
    sh -c '
      for format in ysd.yaml ysdc.yaml ysdc.json schema.json; do
        bin/ysd -t "$format" </dev/null 2>&1 |
          perl -ne "print if $. == 1"
      done
      for format in ysd.yaml ysdc.yaml ysdc.json schema.json; do
        bin/ysd -f "$format" -t jsc </dev/null 2>&1 |
          perl -ne "print if $. == 1"
      done
    '
  want: |
    ysd: unsupported output format: ysd.yaml
    ysd: unsupported output format: ysdc.yaml
    ysd: unsupported output format: ysdc.json
    ysd: unsupported output format: schema.json
    ysd: unsupported input format: ysd.yaml
    ysd: unsupported input format: ysdc.yaml
    ysd: unsupported input format: ysdc.json
    ysd: unsupported input format: schema.json

- name: reject-output-option-conflicts
  cmnd: |
    sh -c '
      bin/ysd -YJ 2>&1 | perl -ne "print if $. == 1"
      bin/ysd -t ysd -o out.ysdc.yaml 2>&1 |
        perl -ne "print if $. == 1"
      bin/ysd -t ysdc -J -o out.ysdc.yaml 2>&1 |
        perl -ne "print if $. == 1"
      bin/ysd -N -o out.ysd.json 2>&1 |
        perl -ne "print if $. == 1"
      bin/ysd -t ysd -CY 2>&1 | perl -ne "print if $. == 1"
      bin/ysd -R -Y 2>&1 | perl -ne "print if $. == 1"
    '
  want: |
    ysd: -Y/--yaml cannot be combined with -J/--json
    ysd: output format conflicts with file extension: out.ysdc.yaml
    ysd: output encoding conflicts with file extension: out.ysdc.yaml
    ysd: output format conflicts with file extension: out.ysd.json
    ysd: -C/--compact requires JSON output
    ysd: -R/--roundtrip cannot use -Y/--yaml or -J/--json

- name: schema-errors-omit-usage
  cmnd: |
    sh -c '
      output=$(bin/ysd - --to jsc 2>&1)
      status=$?
      printf "%s\nstatus=%s\n" "$output" "$status"
    '
  stdi: |
    foo: ==bar
  want: |
    ysd: const requires a preceding type reference
    status=1

- name: norm-compact
  cmnd: bin/ysd -NC
  stdi: |
    {
      "$schema": "http://json-schema.org/draft-07/schema#",
      "definitions": {"thing": {"type": "string"}}
    }
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","$defs":{"thing":{"type":"string"}}}

- name: norm-yaml
  cmnd: bin/ysd -NY -f jsc
  stdi: |
    {"type":"object"}
  want: |
    $schema: https://json-schema.org/draft/2020-12/schema
    type: object

- name: norm
  cmnd: bin/ysd -N
  stdi: |
    {
      "$schema": "http://json-schema.org/draft-07/schema#",
      "definitions": {"thing": {"type": "string"}},
      "properties": {"name": {"$ref": "#/definitions/thing"}}
    }
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$defs": {
        "thing": {
          "type": "string"
        }
      },
      "properties": {
        "name": {
          "$ref": "#/$defs/thing"
        }
      }
    }

- name: norm-canonicalizes-explicit-open-objects
  cmnd: bin/ysd -NC
  stdi: |
    {
      "type": "object",
      "additionalProperties": true,
      "properties": {
        "open": {"type": "object", "additionalProperties": true},
        "empty": {"type": "object", "additionalProperties": {}},
        "closed": {"type": "object", "additionalProperties": false},
        "typed": {
          "type": "object",
          "additionalProperties": {"type": "string"}
        },
        "data": {
          "default": {
            "additionalProperties": true,
            "definitions": {"x": {"type": "string"}},
            "$ref": "#/definitions/x"
          }
        }
      }
    }
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"open":{"type":"object"},"empty":{"type":"object"},"closed":{"type":"object","additionalProperties":false},"typed":{"type":"object","additionalProperties":{"type":"string"}},"data":{"default":{"additionalProperties":true,"definitions":{"x":{"type":"string"}},"$ref":"#\/definitions\/x"}}}}

- name: norm-canonicalizes-single-ref-allof
  cmnd: bin/ysd -NC
  stdi: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$defs": {"base": {"type": "object"}},
      "type": "object",
      "properties": {
        "inherited": {
          "type": "object",
          "allOf": [{"$ref": "#/$defs/base"}],
          "properties": {"local": {"type": "integer"}}
        },
        "rich": {
          "allOf": [{"$ref": "#/$defs/base", "title": "Branch"}]
        }
      }
    }
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","$defs":{"base":{"type":"object"}},"type":"object","properties":{"inherited":{"type":"object","$ref":"#\/$defs\/base","properties":{"local":{"type":"integer"}}},"rich":{"allOf":[{"title":"Branch","$ref":"#\/$defs\/base"}]}}}

- name: norm-warns-for-float-export
  cmnd: sh -c 'bin/ysd -f ysd -NC - 2>&1'
  stdi: |
    precise: +Float
  want: |
    ysd: warning: +Float at /properties/precise exports as JSON Schema "number", which also accepts integers
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"precise":{"type":"number"}},"required":["precise"],"additionalProperties":false}

- name: roundtrip-match
  cmnd: bin/ysd --roundtrip -f jsc -
  stdi: |
    {
      "type": "object",
      "properties": {"foo": {"type": "string"}},
      "required": ["foo"],
      "additionalProperties": false
    }
  want: |
    OK

- name: roundtrip-detects-json-content
  cmnd: bin/ysd --roundtrip -
  stdi: |

      {
        "type": "object",
        "additionalProperties": false
      }
  want: |
    OK

- name: roundtrip-detects-ysd-content
  cmnd: bin/ysd --roundtrip -
  stdi: |
    .title: Person
    .open: true
    age?: +Int 0..
    name: +Str
  want: |
    OK

- name: roundtrip-content-over-file-extension
  cmnd: |
    sh -c '
      file=$(mktemp --suffix=.schema.json)
      printf "%s\n" ".title: Person" ".open: true" \
        "name: +Str" > "$file"
      bin/ysd -R "$file"
      status=$?
      rm "$file"
      exit "$status"
    '
  want: |
    OK

- name: roundtrip-explicit-format-precedence
  cmnd: bin/ysd --roundtrip -f ysd -
  stdi: |
    {.open: true, name: +Str}
  want: |
    OK

- name: ysd-roundtrip-mismatch
  cmnd: |
    sh -c '
      output=$(printf "%s\n" ".open: true" "value: +Float 0.." |
        bin/ysd -R -f ysd - 2>/dev/null)
      status=$?
      test "$status" -eq 1
      printf "status=%s\n%s\n" "$status" "$output"
    '
  want: |
    status=1
    --- original
    +++ roundtrip
    @@ -1,4 +1,4 @@
     .open: true
     value:
    -  .type: +Float
    +  .type: +Num
       .range: [0]

- name: roundtrip-mismatch
  cmnd: |
    sh -c '
      output=$(printf "%s\n" "{\"minimum\":1}" |
        bin/ysd -R -f jsc -)
      status=$?
      test "$status" -eq 1
      printf "status=%s\n%s\n" "$status" "$output"
    '
  want: |
    status=1
    --- original
    +++ roundtrip
    @@ -1,4 +1,5 @@
     {
       "$schema": "https://json-schema.org/draft/2020-12/schema",
    -  "minimum": 1
    +  "type": "object",
    +  "additionalProperties": false
     }

- name: roundtrip-diff-uses-less
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "%s\n" \
        "#!/bin/sh" \
        "printf \"%s\n\" \"\$*\" > \"\$LESS_LOG\"" \
        "cat" > "$dir/less"
      chmod +x "$dir/less"
      output=$(printf "%s\n" "{\"minimum\":1}" |
        PATH="$dir:$PATH" LESS_LOG="$dir/less.log" \
        bin/ysd -R -f jsc -)
      status=$?
      args=$(cat "$dir/less.log")
      rm -r "$dir"
      test "$status" -eq 1
      test "$(printf "%s\n" "$output" | sed -n 1p)" = "--- original"
      printf "status=%s args=%s\n" "$status" "$args"
    '
  want: |
    status=1 args=-FRX

- name: roundtrip-diff-without-less
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      ys=$(command -v ys-0)
      case "$ys" in
        /*) ;;
        *) ys=$(pwd)/$ys ;;
      esac
      ln -s "$ys" "$dir/ys-0"
      ln -s "$(command -v bash)" "$dir/bash"
      ln -s "$(command -v diff)" "$dir/diff"
      ln -s "$(command -v mktemp)" "$dir/mktemp"
      output=$(printf "%s\n" "{\"minimum\":1}" |
        PATH="$dir" bin/ysd -R -f jsc -)
      status=$?
      rm -r "$dir"
      test "$status" -eq 1
      printf "%s\n" "$output" | sed -n 1p
    '
  want: |
    --- original

- name: roundtrip-quiet-status
  cmnd: |
    sh -c '
      same=$(printf "%s\n" \
        "{\"type\":\"object\",\"additionalProperties\":false}" |
        bin/ysd -Rq -f jsc - 2>&1)
      same_status=$?
      changed=$(printf "%s\n" "{\"minimum\":1}" |
        bin/ysd -R --quiet -f jsc - 2>&1)
      changed_status=$?
      broken=$(printf "%s\n" "{bad" |
        bin/ysd -Rq -f jsc - 2>&1)
      broken_status=$?
      test -z "$same"
      test -z "$changed"
      test -z "$broken"
      printf "%s %s %s\n" \
        "$same_status" "$changed_status" "$broken_status"
    '
  want: |
    0 1 2

- name: roundtrip-rejects-other-input-format
  cmnd: |
    sh -c '
      output=$(printf "%s\n" "foo: +Str" |
        bin/ysd -R -f ysdc - 2>&1)
      status=$?
      test "$status" -eq 2
      printf "%s\n" "$output" | perl -ne "print if $. == 1"
    '
  want: |
    ysd: -R/--roundtrip requires JSON Schema or .ysd input

- name: reject-roundtrip-option-conflicts
  cmnd: |
    sh -c '
      bin/ysd -RN 2>&1 | sed -n 1p
      bin/ysd -RC 2>&1 | sed -n 1p
      bin/ysd -R -t jsc 2>&1 | sed -n 1p
      bin/ysd -R -o out.schema.json 2>&1 | sed -n 1p
      bin/ysd -q 2>&1 | sed -n 1p
    '
  want: |
    ysd: -R/--roundtrip cannot be combined with -N/--norm
    ysd: -R/--roundtrip cannot be combined with -C/--compact
    ysd: -R/--roundtrip cannot be combined with -t/--to
    ysd: -R/--roundtrip cannot be combined with -o/--output
    ysd: -q/--quiet requires -R/--roundtrip

- name: stdin-default-with-to
  cmnd: bin/ysd -t ysd
  stdi: |
    {
      "type": "object",
      "properties": {
        "name": {"type": "string"}
      },
      "required": ["name"]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    name: +Str

- name: json-schema-def-order-to-ysdc
  cmnd: bin/ysd -t ysd
  stdi: |
    {
      "definitions": {
        "alpha": {"type": "string"},
        "bravo": {"type": "string"},
        "charlie": {"type": "string"},
        "delta": {"type": "string"},
        "echo": {"type": "string"},
        "foxtrot": {"type": "string"},
        "golf": {"type": "string"},
        "hotel": {"type": "string"},
        "india": {"type": "string"},
        "juliet": {"type": "string"}
      }
    }
  want: |
    # Converted from JSON Schema

    +alpha: +Str

    +bravo: +Str

    +charlie: +Str

    +delta: +Str

    +echo: +Str

    +foxtrot: +Str

    +golf: +Str

    +hotel: +Str

    +india: +Str

    +juliet: +Str

- name: compact-schema-json
  cmnd: sh -c 'bin/ysd -t jsc -C | wc -l'
  stdi: |
    s: +Str
  want: |
    1

done:
