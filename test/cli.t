#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: no-args
  cmnd: bin/ysc
  want: |
    Usage: ysc (-t FORMAT | -o FILE) [INPUT]
           ysc -N, --norm [INPUT]
           ysc -R, --roundtrip [-q, --quiet] [INPUT]

    Convert between JSON Schema and yamlschema formats.

    Arguments:
      INPUT                 Input schema path. Defaults to stdin.

    Options:
      -t, --to FORMAT       Output format: ysd, yscy, yscj, or jsc.
      -f, --from FORMAT     Input format: ysd, yscy, yscj, or jsc.
      -o, --output FILE     Write output to FILE. Use "-" for stdout.
      -N, --norm            Normalize input to draft 2020-12 JSON Schema.
      -R, --roundtrip       Check JSON Schema roundtrip through YSD.
      -q, --quiet           Suppress roundtrip output.
      -C, --compact         Emit compact JSON output.
          --help            Show this help text.
          --version         Show version.

- name: help
  cmnd: bin/ysc --help
  want: |
    Usage: ysc (-t FORMAT | -o FILE) [INPUT]
           ysc -N, --norm [INPUT]
           ysc -R, --roundtrip [-q, --quiet] [INPUT]

    Convert between JSON Schema and yamlschema formats.

    Arguments:
      INPUT                 Input schema path. Defaults to stdin.

    Options:
      -t, --to FORMAT       Output format: ysd, yscy, yscj, or jsc.
      -f, --from FORMAT     Input format: ysd, yscy, yscj, or jsc.
      -o, --output FILE     Write output to FILE. Use "-" for stdout.
      -N, --norm            Normalize input to draft 2020-12 JSON Schema.
      -R, --roundtrip       Check JSON Schema roundtrip through YSD.
      -q, --quiet           Suppress roundtrip output.
      -C, --compact         Emit compact JSON output.
          --help            Show this help text.
          --version         Show version.

- name: version
  cmnd: bin/ysc --version
  want: |
    ysc 0.1.0

- name: reject-removed-format-options
  cmnd: |
    sh -c '
      bin/ysc -F 2>&1 | sed -n 1p
      bin/ysc --fmt 2>&1 | sed -n 1p
    '
  want: |
    ysc: unknown option -F
    ysc: unknown option --fmt

- name: norm-compact
  cmnd: bin/ysc -NC
  stdi: |
    {
      "$schema": "http://json-schema.org/draft-07/schema#",
      "definitions": {"thing": {"type": "string"}}
    }
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","$defs":{"thing":{"type":"string"}}}

- name: norm
  cmnd: bin/ysc -N
  stdi: |
    {
      "$schema": "http://json-schema.org/draft-07/schema#",
      "definitions": {"thing": {"type": "string"}},
      "properties": {"name": {"$ref": "#/definitions/thing"}}
    }
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "properties": {
        "name": {
          "$ref": "#/$defs/thing"
        }
      },
      "$defs": {
        "thing": {
          "type": "string"
        }
      }
    }

- name: norm-canonicalizes-explicit-open-objects
  cmnd: bin/ysc -NC
  stdi: |
    {
      "type": "object",
      "additionalProperties": true,
      "properties": {
        "open": {"type": "object", "additionalProperties": true},
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
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"closed":{"type":"object","additionalProperties":false},"data":{"default":{"$ref":"#\/definitions\/x","additionalProperties":true,"definitions":{"x":{"type":"string"}}}},"open":{"type":"object"},"typed":{"type":"object","additionalProperties":{"type":"string"}}}}

- name: norm-warns-for-float-export
  cmnd: sh -c 'bin/ysc -f ysd -NC - 2>&1'
  stdi: |
    precise: +Float
  want: |
    ysc: warning: +Float at /properties/precise exports as JSON Schema "number", which also accepts integers
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"precise":{"type":"number"}},"required":["precise"],"additionalProperties":false}

- name: roundtrip-match
  cmnd: bin/ysc --roundtrip -f jsc -
  stdi: |
    {
      "type": "object",
      "properties": {"foo": {"type": "string"}},
      "required": ["foo"],
      "additionalProperties": false
    }
  want: |
    OK

- name: roundtrip-mismatch
  cmnd: |
    sh -c '
      output=$(printf "%s\n" "{\"minimum\":1}" |
        bin/ysc -R -f jsc -)
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
        bin/ysc -R -f jsc -)
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
      ln -s "$(command -v ys-0)" "$dir/ys-0"
      ln -s "$(command -v bash)" "$dir/bash"
      ln -s "$(command -v diff)" "$dir/diff"
      ln -s "$(command -v mktemp)" "$dir/mktemp"
      output=$(printf "%s\n" "{\"minimum\":1}" |
        PATH="$dir" bin/ysc -R -f jsc -)
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
        bin/ysc -Rq -f jsc - 2>&1)
      same_status=$?
      changed=$(printf "%s\n" "{\"minimum\":1}" |
        bin/ysc -R --quiet -f jsc - 2>&1)
      changed_status=$?
      broken=$(printf "%s\n" "{bad" |
        bin/ysc -Rq -f jsc - 2>&1)
      broken_status=$?
      test -z "$same"
      test -z "$changed"
      test -z "$broken"
      printf "%s %s %s\n" \
        "$same_status" "$changed_status" "$broken_status"
    '
  want: |
    0 1 2

- name: roundtrip-requires-json-schema
  cmnd: |
    sh -c '
      output=$(printf "%s\n" "foo: +Str" |
        bin/ysc -R -f ysd - 2>&1)
      status=$?
      test "$status" -eq 2
      printf "%s\n" "$output" | sed -n 1p
    '
  want: |
    ysc: -R/--roundtrip requires JSON Schema input

- name: reject-roundtrip-option-conflicts
  cmnd: |
    sh -c '
      bin/ysc -RN 2>&1 | sed -n 1p
      bin/ysc -RC 2>&1 | sed -n 1p
      bin/ysc -R -t jsc 2>&1 | sed -n 1p
      bin/ysc -R -o out.schema.json 2>&1 | sed -n 1p
      bin/ysc -q 2>&1 | sed -n 1p
    '
  want: |
    ysc: -R/--roundtrip cannot be combined with -N/--norm
    ysc: -R/--roundtrip cannot be combined with -C/--compact
    ysc: -R/--roundtrip cannot be combined with -t/--to
    ysc: -R/--roundtrip cannot be combined with -o/--output
    ysc: -q/--quiet requires -R/--roundtrip

- name: stdin-default-with-to
  cmnd: bin/ysc -t ysd
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

- name: json-schema-def-order-to-ysc
  cmnd: bin/ysc -t ysd
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
    .open: true

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
  cmnd: sh -c 'bin/ysc -t jsc -C | wc -l'
  stdi: |
    s: +Str
  want: |
    1

done:
