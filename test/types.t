#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: types
  cmnd: bin/ysd -t ysd -
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

- name: unconstrained-and-closed-schemas
  cmnd: bin/ysd -f jsc -t ysd -
  stdi: |
    {
      "type": "object",
      "properties": {
        "anything": {},
        "closed": {
          "type": "object",
          "additionalProperties": false
        }
      },
      "additionalProperties": false
    }
  want: |
    # Converted from JSON Schema
    anything?: +Any
    closed?: {}

- name: unconstrained-schema-roundtrip
  cmnd: bin/ysd -R -f jsc -
  stdi: |
    {
      "type": "object",
      "properties": {
        "default": {}
      },
      "additionalProperties": false
    }
  want: |
    OK

- name: yaml-number-inference
  cmnd: bin/ysd -t ysdc -J -C -
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
  cmnd: bin/ysd -t ysd -
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
  cmnd: sh -c 'bin/ysd -f ysd -t jsc -C - 2>&1'
  stdi: |
    +measurement: +Float
    number: +Num
    float: +Float
    floats: +Float[]
    choice: +One(+Int,+Float)
    nested:
      reading?: +Float
  want: |
    ysd: warning: +Float at /$defs/measurement exports as JSON Schema "number", which also accepts integers
    ysd: warning: +Float at /properties/float exports as JSON Schema "number", which also accepts integers
    ysd: warning: +Float at /properties/floats/items exports as JSON Schema "number", which also accepts integers
    ysd: warning: +Float at /properties/choice/oneOf/1 exports as JSON Schema "number", which also accepts integers
    ysd: warning: +Float at /properties/nested/properties/reading exports as JSON Schema "number", which also accepts integers
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","$defs":{"measurement":{"type":"number"}},"type":"object","properties":{"number":{"type":"number"},"float":{"type":"number"},"floats":{"type":"array","items":{"type":"number"}},"choice":{"oneOf":[{"type":"integer"},{"type":"number"}]},"nested":{"type":"object","properties":{"reading":{"type":"number"}},"additionalProperties":false}},"required":["number","float","floats","choice","nested"],"additionalProperties":false}

- name: reject-unknown-capitalized-type-references
  cmnd: |
    sh -c '
      for value in \
        "+Stx" \
        "+Stx[]" \
        "+Map{+Stx}" \
        "+One(+Str,+Stx)"; do
        printf "value: %s\n" "$value" |
          bin/ysd -f ysd -t jsc - 2>&1 |
          perl -ne "print if \$. == 1"
      done
    '
  want: |
    ysd: unknown yamlschema built-in type: +Stx
    ysd: unknown yamlschema built-in type: +Stx
    ysd: unknown yamlschema built-in type: +Stx
    ysd: unknown yamlschema built-in type: +Stx

- name: reject-malformed-plus-prefixed-type
  cmnd: |
    sh -c '
      printf "value: +Stx(\n" |
        bin/ysd -f ysd -t jsc - 2>&1 |
        perl -ne "print if \$. == 1"
    '
  want: |
    ysd: invalid yamlschema type expression: +Stx(

done:
