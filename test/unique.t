#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: unique
  cmnd: bin/ysd -t ysd.yaml -
  stdi: |
    {
      "properties": {
        "tags": {
          "type": "array",
          "items": {"type": "string"},
          "uniqueItems": true
        },
        "names": {
          "type": "array",
          "items": {"type": "string"},
          "uniqueItems": true,
          "minItems": 1
        },
        "triple": {
          "type": "array",
          "items": {"type": "integer"},
          "uniqueItems": true,
          "minItems": 3,
          "maxItems": 3
        },
        "subset": {
          "type": "array",
          "items": {"type": "string"},
          "uniqueItems": true,
          "minItems": 1,
          "maxItems": 3
        }
      },
      "required": ["tags", "names", "triple", "subset"]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    tags: +Str[!]
    names: +Str[1+,!]
    triple: +Int[3,!]
    subset: +Str[1-3,!]

done:
