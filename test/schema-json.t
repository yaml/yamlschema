#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: types-to-schema-json
  cmnd: bin/ysc -t schema.json -
  stdi: |
    s: +Str
    i: +Int
    n: +Float
    b: +Bool
  want: |
    {"type":"object","properties":{"s":{"type":"string"},"i":{"type":"integer"},"n":{"type":"number"},"b":{"type":"boolean"}},"required":["s","i","n","b"]}

- name: refs-and-regex-to-schema-json
  cmnd: bin/ysc -t schema.json -
  stdi: |
    +email: /^\S+@\S+$/

    host: +Str
    admin?: +email
  want: |
    {"$defs":{"email":{"type":"string","pattern":"^\\S+@\\S+$"}},"type":"object","properties":{"host":{"type":"string"},"admin":{"$ref":"#\/$defs\/email"}},"required":["host"]}

- name: list-suffix-to-schema-json
  cmnd: bin/ysc -t schema.json -
  stdi: |
    tags[!+]: +Str
  want: |
    {"type":"object","properties":{"tags":{"type":"array","items":{"type":"string"},"uniqueItems":true,"minItems":1}},"required":["tags"]}

- name: explicit-block-to-schema-json
  cmnd: bin/ysc -t schema.json -
  stdi: |
    port:
      -type: +Int
      -size: [1, 65535]
      -init: 8080
  want: |
    {"type":"object","properties":{"port":{"type":"integer","minimum":1,"maximum":65535,"default":8080}},"required":["port"]}

done:
