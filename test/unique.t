#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: unique
  cmnd: bin/ysc -t ysd.yaml -
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
    tags[!]: +Str
    names[!1+]: +Str
    triple[!3]: +Int
    subset[!1-3]: +Str

done:
