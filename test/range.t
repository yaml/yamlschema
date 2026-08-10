#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: range
  cmnd: bin/ysc -t ysd.yaml -
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
    port: +Int 1..65535
    age: +Int 0..
    ratio: +Float 0..1
    debt: +Int ..-1

- name: range-expansion
  cmnd: bin/ysc -t yscj -
  stdi: |
    port: +Int 1..65535
    age: range:0..
    ratio:
      .base: +Float
      .range: 0..1
    debt: +Int range:..-1
  want: |
    {
      "port": {
        ".base": "+Int",
        ".range": [
          1,
          65535
        ]
      },
      "age": {
        ".base": "+Int",
        ".range": [
          0
        ]
      },
      "ratio": {
        ".base": "+Float",
        ".range": [
          0,
          1
        ]
      },
      "debt": {
        ".base": "+Int",
        ".range": [
          null,
          -1
        ]
      }
    }

- name: structural-ranges-to-json-schema
  cmnd: bin/ysc -f yscy -t jsc -
  stdi: |
    lower:
      .base: +Int
      .range: [0]
    upper:
      .base: +Int
      .range: [null, -1]
    bounded:
      .base: +Float
      .range: [0.5, 1]
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "bounded": {
          "type": "number",
          "minimum": 0.5,
          "maximum": 1
        },
        "lower": {
          "type": "integer",
          "minimum": 0
        },
        "upper": {
          "type": "integer",
          "maximum": -1
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
