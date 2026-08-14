#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: no-args
  cmnd: bin/ysc
  want: |
    Usage: ysc (-t FORMAT | -o FILE) [INPUT]
           ysc -F, --fmt [INPUT]
           ysc -N, --norm [INPUT]

    Convert between JSON Schema and yamlschema formats.

    Arguments:
      INPUT                 Input schema path. Defaults to stdin.

    Options:
      -t, --to FORMAT       Output format: ysd, yscy, yscj, or jsc.
      -f, --from FORMAT     Input format: ysd, yscy, yscj, or jsc.
      -o, --output FILE     Write output to FILE. Use "-" for stdout.
      -F, --fmt             Format JSON Schema to stdout.
      -N, --norm            Normalize JSON Schema to draft 2020-12 on stdout.
      -C, --compact         Emit compact JSON output.
          --help            Show this help text.
          --version         Show version.

- name: help
  cmnd: bin/ysc --help
  want: |
    Usage: ysc (-t FORMAT | -o FILE) [INPUT]
           ysc -F, --fmt [INPUT]
           ysc -N, --norm [INPUT]

    Convert between JSON Schema and yamlschema formats.

    Arguments:
      INPUT                 Input schema path. Defaults to stdin.

    Options:
      -t, --to FORMAT       Output format: ysd, yscy, yscj, or jsc.
      -f, --from FORMAT     Input format: ysd, yscy, yscj, or jsc.
      -o, --output FILE     Write output to FILE. Use "-" for stdout.
      -F, --fmt             Format JSON Schema to stdout.
      -N, --norm            Normalize JSON Schema to draft 2020-12 on stdout.
      -C, --compact         Emit compact JSON output.
          --help            Show this help text.
          --version         Show version.

- name: version
  cmnd: bin/ysc --version
  want: |
    ysc 0.1.0

- name: fmt
  cmnd: bin/ysc -F
  stdi: |
    {
      "type": "object",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "x",
      "$defs": {"b": {"type": "string"}}
    }
  want: |
    {
      "$id": "x",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "$defs": {
        "b": {
          "type": "string"
        }
      }
    }

- name: fmt-compact
  cmnd: bin/ysc -FC
  stdi: |
    {
      "type": "object",
      "$id": "x"
    }
  want: |
    {"$id":"x","type":"object"}

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
