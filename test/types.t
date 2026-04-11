#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: types
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "s": {"type": "string"},
        "i": {"type": "integer"},
        "n": {"type": "number"},
        "b": {"type": "boolean"}
      },
      "required": ["s", "i", "n", "b"]
    }
  want: |
    s: +Str
    i: +Int
    n: +Float
    b: +Bool

done:
