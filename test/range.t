#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: range
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "port":  {"type": "integer", "minimum": 1, "maximum": 65535},
        "age":   {"type": "integer", "minimum": 0},
        "ratio": {"type": "number",  "minimum": 0, "maximum": 1}
      },
      "required": ["port", "age", "ratio"]
    }
  want: |
    port: 1-65535
    age: 0-*
    ratio: 0-1

done:
