#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: range
  cmnd: bin/ysd -t ysd -
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

- name: exclusive-range-import
  cmnd: bin/ysd -f jsc -t ysd -
  stdi: |
    {
      "type": "object",
      "properties": {
        "lower": {
          "type": "number",
          "minimum": 0,
          "exclusiveMinimum": true
        },
        "upper": {
          "type": "number",
          "maximum": 10,
          "exclusiveMaximum": true
        },
        "xmin": {
          "type": "number",
          "minimum": 0,
          "maximum": 10,
          "exclusiveMinimum": true
        },
        "both": {
          "type": "number",
          "minimum": 0,
          "maximum": 10,
          "exclusiveMinimum": true,
          "exclusiveMaximum": true
        }
      },
      "additionalProperties": false
    }
  want: |
    # Converted from JSON Schema
    lower?: +Num 0...
    upper?: +Num ...10
    xmin?: +Num 0..10 :xmin
    both?: +Num 0..10 :xmin :xmax

- name: exclusive-range-canonical-import-with-passthrough
  cmnd: sh -c 'bin/ysd -f jsc -t ysdc -J -C - 2>&1'
  stdi: |
    {
      "type": "object",
      "properties": {
        "step": {
          "type": "number",
          "minimum": 0,
          "exclusiveMinimum": true,
          "multipleOf": 0.5
        }
      },
      "additionalProperties": false
    }
  want: |
    ysd: warning: unsupported JSON Schema keyword "multipleOf" at /properties/step/multipleOf
    {"step?":{".type":"+Num",".range":[0],".xmin":true,".multipleOf":0.5}}

- name: range-expansion
  cmnd: bin/ysd -t ysdc -J -
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

- name: exclusive-range-expansion
  cmnd: bin/ysd -t ysdc -J -C -
  stdi: |
    lower: +Num 0...
    upper: +Num ...10
    xmin: +Num 0..10 :xmin
    xmax: +Num 0..10 :xmax
    both: +Num 0..10 :xmin :xmax
  want: |
    {"lower":{".type":"+Num",".range":[0],".xmin":true},"upper":{".type":"+Num",".range":[null,10],".xmax":true},"xmin":{".type":"+Num",".range":[0,10],".xmin":true},"xmax":{".type":"+Num",".range":[0,10],".xmax":true},"both":{".type":"+Num",".range":[0,10],".xmin":true,".xmax":true}}

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
      "additionalProperties": false,
      "required": [
        "lower",
        "upper",
        "bounded"
      ],
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
      }
    }

- name: exclusive-ranges-to-json-schema
  cmnd: bin/ysd -f ysdc -t jsc -J -C -
  stdi: |
    lower:
      .type: +Num
      .range: [0]
      .xmin: true
    upper:
      .type: +Num
      .range: [null, 10]
      .xmax: true
    both:
      .type: +Num
      .range: [0, 10]
      .xmin: true
      .xmax: true
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":false,"required":["lower","upper","both"],"properties":{"lower":{"type":"number","minimum":0,"exclusiveMinimum":true},"upper":{"type":"number","maximum":10,"exclusiveMaximum":true},"both":{"type":"number","minimum":0,"maximum":10,"exclusiveMaximum":true,"exclusiveMinimum":true}}}

- name: exclusive-range-validation-errors
  cmnd: |
    sh -c '
      for input in \
        "bad: +Num 0...10" \
        "bad: +Num 0.. :xmax" \
        "bad: +Num ..10 :xmin" \
        "bad: :xmin" \
        "bad:\n  .type: +Num\n  .xmin: true" \
        "bad:\n  .type: +Num\n  .range: [0]\n  .xmin: false"; do
        printf "%b\n" "$input" |
          bin/ysd -t ysdc -J -C - 2>&1 |
          perl -ne "print if \$. == 1"
      done
    '
  want: |
    ysd: ambiguous yamlschema range: 0...10; use .. with :xmin or :xmax
    ysd: yamlschema .xmax requires an upper range bound
    ysd: yamlschema .xmin requires a lower range bound
    ysd: :xmin requires a preceding range
    ysd: yamlschema .xmin requires a .range directive
    ysd: yamlschema .xmin must be true

done:
