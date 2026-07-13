#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: no-args
  cmnd: bin/ysc
  want: |
    Usage: ysc (-t FORMAT | -o FILE) INPUT
           ysc --fmt INPUT
           ysc --norm INPUT

    Convert between JSON Schema and yamlschema formats.

    Arguments:
      INPUT                 Input schema path. Use "-" for stdin.

    Options:
      -t, --to FORMAT       Output format. Supports "ysc.yaml", "schema.json".
      -o, --output FILE     Write output to FILE. Use "-" for stdout.
      -P, --pretty          Pretty-print JSON output with 2-space indentation.
          --fmt             Format a JSON Schema file to stdout.
          --norm            Normalize JSON Schema to draft 2020-12 on stdout.
          --help            Show this help text.
          --version         Show version.

- name: help
  cmnd: bin/ysc --help
  want: |
    Usage: ysc (-t FORMAT | -o FILE) INPUT
           ysc --fmt INPUT
           ysc --norm INPUT

    Convert between JSON Schema and yamlschema formats.

    Arguments:
      INPUT                 Input schema path. Use "-" for stdin.

    Options:
      -t, --to FORMAT       Output format. Supports "ysc.yaml", "schema.json".
      -o, --output FILE     Write output to FILE. Use "-" for stdout.
      -P, --pretty          Pretty-print JSON output with 2-space indentation.
          --fmt             Format a JSON Schema file to stdout.
          --norm            Normalize JSON Schema to draft 2020-12 on stdout.
          --help            Show this help text.
          --version         Show version.

- name: version
  cmnd: bin/ysc --version
  want: |
    ysc 0.1.0

- name: fmt
  cmnd: bin/ysc --fmt -
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

- name: norm
  cmnd: bin/ysc --norm -
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

done:
