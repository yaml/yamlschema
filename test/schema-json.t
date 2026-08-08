#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: types-to-schema.json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    s: +Str
    i: +Int
    n: +Float
    b: +Bool
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"b":{"type":"boolean"},"i":{"type":"integer"},"n":{"type":"number"},"s":{"type":"string"}},"required":["s","i","n","b"],"additionalProperties":false}

- name: refs-and-regex-to-schema.json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    +email: +Str =~"\S+@\S+"

    host: +Str
    admin?: +email
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"admin":{"$ref":"#\/$defs\/email"},"host":{"type":"string"}},"required":["host"],"additionalProperties":false,"$defs":{"email":{"type":"string","pattern":"^\\S+@\\S+$"}}}

- name: match-find-and-regex-to-schema.json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    full: =~"abc"
    alias: match:"xyz"
    found: find:"abc"
    short: /abc/
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"alias":{"type":"string","pattern":"^xyz$"},"found":{"type":"string","pattern":"abc"},"full":{"type":"string","pattern":"^abc$"},"short":{"type":"string","pattern":"abc"}},"required":["full","alias","found","short"],"additionalProperties":false}

- name: defs-only-to-schema.json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    +airflow: +Str [front-to-rear,rear-to-front]
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":false,"$defs":{"airflow":{"type":"string","enum":["front-to-rear","rear-to-front"]}}}

- name: compact-enum-to-schema.json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    role: +Str [admin,user,guest]
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"role":{"type":"string","enum":["admin","user","guest"]}},"required":["role"],"additionalProperties":false}

- name: list-suffix-to-schema.json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    tags[!+]: +Str
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"tags":{"type":"array","items":{"type":"string"},"uniqueItems":true,"minItems":1}},"required":["tags"],"additionalProperties":false}

- name: explicit-block-to-schema.json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    port:
      .base: +Int
      .range: 1..65535
      .init: 8080
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"port":{"type":"integer","default":8080,"minimum":1,"maximum":65535}},"required":["port"],"additionalProperties":false}

- name: numeric-range-shorthand-to-schema.json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    port: 1..65535
    age: 0..
    debt: ..-1
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"age":{"type":"integer","minimum":0},"debt":{"type":"integer","maximum":-1},"port":{"type":"integer","minimum":1,"maximum":65535}},"required":["port","age","debt"],"additionalProperties":false}

- name: annotations-to-schema.json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    .title: Arrays
    .desc: Arrays of strings and objects
    name:
      .base: +Str
      .title: Full name
      .desc: Display name.
    .json:
      $id: https://example.com/arrays.schema.json
  want: |
    {"$id":"https:\/\/example.com\/arrays.schema.json","$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","title":"Arrays","description":"Arrays of strings and objects","type":"object","properties":{"name":{"title":"Full name","description":"Display name.","type":"string"}},"required":["name"],"additionalProperties":false}

- name: wildcard-to-schema.json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    +Str: +Str
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":{"type":"string"}}

- name: any-wildcard-to-schema.json
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    +Str: +Any
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":{}}

- name: wildcard-next-to-definition
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    +label: +Str

    +Str: +label
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":{"$ref":"#\/$defs\/label"},"$defs":{"label":{"type":"string"}}}

- name: nested-shaped-and-open-maps
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    server:
      port: +Int
    data: +Map[+Any]
    labels:
      fixed?: +Str
      +Str:
        .base: +Str
        .size: 1-20
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"data":{"type":"object","additionalProperties":{}},"labels":{"type":"object","properties":{"fixed":{"type":"string"}},"additionalProperties":{"type":"string","minLength":1,"maxLength":20}},"server":{"type":"object","properties":{"port":{"type":"integer"}},"required":["port"],"additionalProperties":false}},"required":["server","data","labels"],"additionalProperties":false}

- name: reject-additional-properties-directive
  cmnd: |
    sh -c '
      output=$(printf "%s\n" "-additionalProperties: false" |
        bin/ysc -t schema.json -C - 2>&1)
      status=$?
      test $status -eq 2
      printf "%s\n" "$output" | sed -n 1p
    '
  want: |
    ysc: unsupported yamlschema directive: -additionalProperties; use +Str

- name: reject-dash-directive
  cmnd: |
    sh -c '
      output=$(printf "%s\n" "field:" "  -base: +Str" |
        bin/ysc -t schema.json -C - 2>&1)
      status=$?
      test $status -eq 2
      printf "%s\n" "$output" | sed -n 1p
    '
  want: |
    ysc: unsupported yamlschema directive: -base; use .base

- name: reject-uppercase-title-directive
  cmnd: |
    sh -c '
      output=$(printf "%s\n" ".Name: Old title" |
        bin/ysc -t schema.json -C - 2>&1)
      status=$?
      test $status -eq 2
      printf "%s\n" "$output" | sed -n 1p
    '
  want: |
    ysc: unsupported yamlschema directive: .Name; use .title

- name: pretty-schema.json
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
      ],
      "additionalProperties": false
    }

done:
