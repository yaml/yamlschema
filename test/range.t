#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: range
  cmnd: bin/ysc -t ysc.yaml -
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
  cmnd: bin/ysc -t ysxj -
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
        ".range": "1..65535"
      },
      "age": {
        ".base": "+Int",
        ".range": "0.."
      },
      "ratio": {
        ".base": "+Float",
        ".range": "0..1"
      },
      "debt": {
        ".base": "+Int",
        ".range": "..-1"
      }
    }

done:
