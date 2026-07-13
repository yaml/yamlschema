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
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"s":{"type":"string"},"i":{"type":"integer"},"n":{"type":"number"},"b":{"type":"boolean"}},"required":["s","i","n","b"]}

- name: refs-and-regex-to-schema-json
  cmnd: bin/ysc -t schema.json -
  stdi: |
    +email: /^\S+@\S+$/

    host: +Str
    admin?: +email
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"host":{"type":"string"},"admin":{"$ref":"#\/$defs\/email"}},"required":["host"],"$defs":{"email":{"type":"string","pattern":"^\\S+@\\S+$"}}}

- name: defs-only-to-schema-json
  cmnd: bin/ysc -t schema.json -
  stdi: |
    +airflow: front-to-rear|rear-to-front
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","$defs":{"airflow":{"enum":["front-to-rear","rear-to-front"]}}}

- name: list-suffix-to-schema-json
  cmnd: bin/ysc -t schema.json -
  stdi: |
    tags[!+]: +Str
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"tags":{"type":"array","items":{"type":"string"},"uniqueItems":true,"minItems":1}},"required":["tags"]}

- name: explicit-block-to-schema-json
  cmnd: bin/ysc -t schema.json -
  stdi: |
    port:
      -type: +Int
      -size: [1, 65535]
      -init: 8080
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"port":{"type":"integer","minimum":1,"maximum":65535,"default":8080}},"required":["port"]}

- name: annotations-to-schema-json
  cmnd: bin/ysc -t schema.json -
  stdi: |
    -Name: Arrays
    -desc: Arrays of strings and objects
    name:
      -type: +Str
      -Name: Full name
      -desc: Display name.
    -json:
      $id: https://example.com/arrays.schema.json
  want: |
    {"$id":"https:\/\/example.com\/arrays.schema.json","$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","title":"Arrays","description":"Arrays of strings and objects","type":"object","properties":{"name":{"type":"string","title":"Full name","description":"Display name."}},"required":["name"]}

- name: pretty-schema-json
  cmnd: bin/ysc -t schema.json -P -
  stdi: |
    s: +Str
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "s": {
          "type": "string"
        }
      },
      "required": [
        "s"
      ]
    }

done:
