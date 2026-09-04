#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: const
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "version": {"const": "v1"},
        "kind":    {"const": "User"},
        "fixed":   {"const": "User", "default": "User"},
        "negative": {"const": -1}
      },
      "required": ["version", "kind", "fixed", "negative"]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    version: +Str ==v1
    kind: +Str ==User
    fixed: +Str ==User =User
    negative: +Int ==-1

- name: negative-const-remains-unambiguous
  cmnd: bin/ysd -t jsc -
  stdi: |
    x: -1
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "x"
      ],
      "properties": {
        "x": {
          "const": -1
        }
      }
    }

done:
