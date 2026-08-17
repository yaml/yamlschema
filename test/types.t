#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: types
  cmnd: bin/ysc -t ysd.yaml -
  stdi: |
    {
      "properties": {
        "s": {"type": "string"},
        "i": {"type": "integer"},
        "n": {"type": "number"},
        "b": {"type": "boolean"}
      },
      "required": ["s", "i", "n", "b"]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    s: +Str
    i: +Int
    n: +Num
    b: +Bool

- name: yaml-number-inference
  cmnd: bin/ysc -t yscj -C -
  stdi: |
    float: 1.5
    float-enum:
      .enum: [1.5, 2.5]
    mixed-enum:
      .enum: [1, 2.5]
    fractional-range: 0.5..1
    integer-range: 0..1
  want: |
    {"float":{".type":"+Float",".const":1.5},"float-enum":{".type":"+Float",".enum":[1.5,2.5]},"mixed-enum":{".type":"+Num",".enum":[1,2.5]},"fractional-range":{".type":"+Num",".range":[0.5,1]},"integer-range":{".type":"+Int",".range":[0,1]}}

- name: json-number-inference
  cmnd: bin/ysc -t ysd -
  stdi: |
    {
      "properties": {
        "decimal": {"enum": [1.5, 2.5]},
        "mixed": {"enum": [1, 2.5]},
        "constant": {"const": 1.5}
      },
      "required": ["decimal", "mixed", "constant"]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    decimal: +Num [1.5, 2.5]
    mixed: +Num [1, 2.5]
    constant: +Num ==1.5

- name: float-export-warning
  cmnd: sh -c 'bin/ysc -f ysd -t jsc -C - 2>&1'
  stdi: |
    +measurement: +Float
    number: +Num
    float: +Float
    floats: +Float[]
    choice: +One(+Int,+Float)
    nested:
      reading?: +Float
  want: |
    ysc: warning: +Float at /$defs/measurement exports as JSON Schema "number", which also accepts integers
    ysc: warning: +Float at /properties/float exports as JSON Schema "number", which also accepts integers
    ysc: warning: +Float at /properties/floats/items exports as JSON Schema "number", which also accepts integers
    ysc: warning: +Float at /properties/choice/oneOf/1 exports as JSON Schema "number", which also accepts integers
    ysc: warning: +Float at /properties/nested/properties/reading exports as JSON Schema "number", which also accepts integers
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"choice":{"oneOf":[{"type":"integer"},{"type":"number"}]},"float":{"type":"number"},"floats":{"type":"array","items":{"type":"number"}},"nested":{"type":"object","properties":{"reading":{"type":"number"}},"additionalProperties":false},"number":{"type":"number"}},"required":["number","float","floats","choice","nested"],"additionalProperties":false,"$defs":{"measurement":{"type":"number"}}}

done:
