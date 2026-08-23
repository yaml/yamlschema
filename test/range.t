#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: range
  cmnd: bin/ysd -t ysd.yaml -
  stdi: |
    {
      "properties": {
        "port":  {"type": "integer", "minimum": 1, "maximum": 65535},
        "age":   {"type": "integer", "minimum": 0},
        "ratio": {"type": "number",  "minimum": 0, "maximum": 1},
        "debt":  {"type": "integer", "maximum": -1}
      },
      "required": ["port", "age", "ratio", "debt"]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    port: +Int 1..65535
    age: +Int 0..
    ratio: +Num 0..1
    debt: +Int ..-1

- name: range-expansion
  cmnd: bin/ysd -t ysdc.json -
  stdi: |
    port: +Int 1..65535
    age: range:0..
    ratio:
      .type: +Float
      .range: 0..1
    debt: +Int range:..-1
  want: |
    {
      "port": {
        ".type": "+Int",
        ".range": [
          1,
          65535
        ]
      },
      "age": {
        ".type": "+Int",
        ".range": [
          0
        ]
      },
      "ratio": {
        ".type": "+Float",
        ".range": [
          0,
          1
        ]
      },
      "debt": {
        ".type": "+Int",
        ".range": [
          null,
          -1
        ]
      }
    }

- name: structural-ranges-to-json-schema
  cmnd: bin/ysd -f ysdc -t jsc -
  stdi: |
    lower:
      .type: +Int
      .range: [0]
    upper:
      .type: +Int
      .range: [null, -1]
    bounded:
      .type: +Num
      .range: [0.5, 1]
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "lower": {
          "type": "integer",
          "minimum": 0
        },
        "upper": {
          "type": "integer",
          "maximum": -1
        },
        "bounded": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 1
        }
      },
      "required": [
        "lower",
        "upper",
        "bounded"
      ],
      "additionalProperties": false
    }

done:
