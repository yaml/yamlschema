#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: length
  cmnd: bin/ysd -t ysd.yaml -
  stdi: |
    {
      "properties": {
        "bio":  {"type": "string", "minLength": 1, "maxLength": 500},
        "code": {"type": "string", "minLength": 3}
      },
      "required": ["bio", "code"]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    bio: +Str 1-500
    code: +Str 3+

done:
