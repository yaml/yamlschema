#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: refs
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "$defs": {
        "port":  {"type": "integer", "minimum": 1, "maximum": 65535},
        "email": {"type": "string",  "pattern": "^\\S+@\\S+$"}
      },
      "properties": {
        "host":  {"type": "string"},
        "port":  {"$ref": "#/$defs/port"},
        "admin": {"$ref": "#/$defs/email"}
      },
      "required": ["host", "port"]
    }
  want: |
    +port: 1-65535
    +email: /^\S+@\S+$/

    host: +Str
    port: +port
    admin?: +email

done:
