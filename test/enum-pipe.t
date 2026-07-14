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

- name: string-enum-pipe
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "type": {"type": "string", "enum": ["8p8c", "8p6c", "8p4c"]}
      }
    }
  want: |
    type?: 8p8c|8p6c|8p4c

- name: dotted-enum-pipe
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "type": {
          "type": "string",
          "enum": ["ieee802.11a", "1.6tbase-cr8"]
        }
      }
    }
  want: |
    type?: ieee802.11a|1.6tbase-cr8

done:
