#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: items
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "tags":    {"type": "array", "items": {"type": "string"}},
        "names":   {"type": "array", "items": {"type": "string"}, "minItems": 1},
        "triple":  {"type": "array", "items": {"type": "integer"}, "minItems": 3, "maxItems": 3},
        "subset":  {"type": "array", "items": {"type": "string"}, "minItems": 1, "maxItems": 3}
      },
      "required": ["tags", "names", "triple", "subset"]
    }
  want: |
    tags[]: +Str
    names[+]: +Str
    triple[3]: +Int
    subset[1-3]: +Str

done:
