#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: pattern
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "email": {"type": "string", "pattern": "^\\S+@\\S+$"},
        "zip":   {"pattern": "^\\d{5}$"}
      },
      "required": ["email", "zip"]
    }
  want: |
    email: /^\S+@\S+$/
    zip: /^\d{5}$/

done:
