#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: types-to-schema-json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    s: +Str
    i: +Int
    n: +Float
    b: +Bool
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"b":{"type":"boolean"},"i":{"type":"integer"},"n":{"type":"number"},"s":{"type":"string"}},"required":["s","i","n","b"]}

- name: refs-and-regex-to-schema-json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    +email: /^\S+@\S+$/

    host: +Str
    admin?: +email
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"admin":{"$ref":"#\/$defs\/email"},"host":{"type":"string"}},"required":["host"],"$defs":{"email":{"type":"string","pattern":"^\\S+@\\S+$"}}}

- name: defs-only-to-schema-json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    +airflow: front-to-rear|rear-to-front
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","$defs":{"airflow":{"type":"string","enum":["front-to-rear","rear-to-front"]}}}

- name: pipe-enum-to-schema-json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    role: admin|user|guest
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"role":{"type":"string","enum":["admin","user","guest"]}},"required":["role"]}

- name: list-suffix-to-schema-json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    tags[!+]: +Str
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"tags":{"type":"array","items":{"type":"string"},"uniqueItems":true,"minItems":1}},"required":["tags"]}

- name: explicit-block-to-schema-json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    port:
      -base: +Int
      -mini: 1
      -maxi: 65535
      -init: 8080
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"port":{"type":"integer","default":8080,"minimum":1,"maximum":65535}},"required":["port"]}

- name: numeric-range-shorthand-to-schema-json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    port: 1..65535
    age: 0..
    debt: ..-1
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"age":{"type":"integer","minimum":0},"debt":{"type":"integer","maximum":-1},"port":{"type":"integer","minimum":1,"maximum":65535}},"required":["port","age","debt"]}

- name: annotations-to-schema-json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    -Name: Arrays
    -desc: Arrays of strings and objects
    name:
      -base: +Str
      -Name: Full name
      -desc: Display name.
    -json:
      $id: https://example.com/arrays.schema.json
  want: |
    {"$id":"https:\/\/example.com\/arrays.schema.json","$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","title":"Arrays","description":"Arrays of strings and objects","type":"object","properties":{"name":{"title":"Full name","description":"Display name.","type":"string"}},"required":["name"]}

- name: additional-properties-to-schema-json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    -additionalProperties: false
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":false}

- name: pretty-schema-json
  cmnd: bin/ysc -t schema.json -
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
