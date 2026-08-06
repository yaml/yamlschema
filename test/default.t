#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: default
  cmnd: bin/ysc -t ysc.yaml -
  stdi: |
    {
      "properties": {
        "port": {"type": "integer", "default": 8080},
        "host": {"type": "string",  "default": "localhost"}
      },
      "required": ["port", "host"]
    }
  want: |
    port:
      .base: +Int
      .init: 8080
    host:
      .base: +Str
      .init: localhost

done:
