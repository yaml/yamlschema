#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: enum-pipe
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "role": {"enum": ["admin", "user", "guest"]},
        "level": {"enum": ["LOW", "MED", "HIGH"]}
      },
      "required": ["role", "level"]
    }
  want: |
    role: admin|user|guest
    level: LOW|MED|HIGH

done:
