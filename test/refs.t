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
    +port: +Int 1..65535
    +email: +Str =~"\S+@\S+"

    host: +Str
    port: +port
    admin?: +email

- name: draft-07-definitions-refs
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "$schema": "http://json-schema.org/draft-07/schema#",
      "definitions": {
        "port":  {"type": "integer", "minimum": 1, "maximum": 65535},
        "email": {"type": "string",  "pattern": "^\\S+@\\S+$"}
      },
      "properties": {
        "host":  {"type": "string"},
        "port":  {"$ref": "#/definitions/port"},
        "admin": {"$ref": "#/definitions/email"}
      },
      "required": ["host", "port"]
    }
  want: |
    +port: +Int 1..65535
    +email: +Str =~"\S+@\S+"

    host: +Str
    port: +port
    admin?: +email

done:
