#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: compact-combinator-expansion
  cmnd: sh -c 'bin/ysc -t yscj -C - | fold -w 72'
  stdi: |
    one: +One[+Str,+Int]
    any: +Any[ +foo, +bar ]
    all: +All[+foo,+bar]
    composed: +base +constraint +other
    not-one: +Not[+foo]
    not-many: +Not[+Str,+Int]
    namespaced: +Any[+net/port,+contact/email]
    values[]: +Any[+foo,+bar]
  want: |
    {"one":{".oneof":["+Str","+Int"]},"any":{".anyof":["+foo","+bar"]},"all"
    :{".allof":["+foo","+bar"]},"composed":{".base":"+base",".allof":["+cons
    traint","+other"]},"not-one":{".not":"+foo"},"not-many":{".not":{".anyof
    ":["+Str","+Int"]}},"namespaced":{".anyof":["+net\/port","+contact\/emai
    l"]},"values":{".list":true,".anyof":["+foo","+bar"]}}

- name: compact-combinators-to-json-schema
  cmnd: bin/ysc -t schema.json -
  stdi: |
    one: +One[+Str,+Int]
    any: +Any[+foo,+bar]
    all: +All[+foo,+bar]
    composed: +base +constraint +other
    not: +Not[+Str,+Int]
    values[]: +Any[+foo,+bar]
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "all": {
          "allOf": [
            {
              "$ref": "#/$defs/foo"
            },
            {
              "$ref": "#/$defs/bar"
            }
          ]
        },
        "any": {
          "anyOf": [
            {
              "$ref": "#/$defs/foo"
            },
            {
              "$ref": "#/$defs/bar"
            }
          ]
        },
        "composed": {
          "$ref": "#/$defs/base",
          "allOf": [
            {
              "$ref": "#/$defs/constraint"
            },
            {
              "$ref": "#/$defs/other"
            }
          ]
        },
        "not": {
          "not": {
            "anyOf": [
              {
                "type": "string"
              },
              {
                "type": "integer"
              }
            ]
          }
        },
        "one": {
          "oneOf": [
            {
              "type": "string"
            },
            {
              "type": "integer"
            }
          ]
        },
        "values": {
          "type": "array",
          "items": {
            "anyOf": [
              {
                "$ref": "#/$defs/foo"
              },
              {
                "$ref": "#/$defs/bar"
              }
            ]
          }
        }
      },
      "required": [
        "one",
        "any",
        "all",
        "composed",
        "not",
        "values"
      ],
      "additionalProperties": false
    }

- name: json-schema-to-compact-combinators
  cmnd: bin/ysc -t ysd.yaml -
  stdi: |
    {
      "properties": {
        "one": {"oneOf": [{"type": "string"}, {"type": "integer"}]},
        "any": {"anyOf": [{"$ref": "#/$defs/foo"},
                            {"$ref": "#/$defs/bar"}]},
        "all": {"allOf": [{"$ref": "#/$defs/foo"},
                            {"$ref": "#/$defs/bar"}]},
        "not": {"not": {"anyOf": [{"type": "string"},
                                      {"type": "integer"}]}}
      }
    }
  want: |
    one?: +One[+Str,+Int]
    any?: +Any[+foo,+bar]
    all?: +All[+foo,+bar]
    not?: +Not[+Str,+Int]

- name: rich-combinators-stay-explicit
  cmnd: bin/ysc -t ysd.yaml -
  stdi: |
    {
      "properties": {
        "choice": {
          "oneOf": [
            {"type": "string", "minLength": 1},
            {"type": "object", "properties": {
              "name": {"type": "string"}}, "required": ["name"]}
          ]
        },
        "negative": {"not": {"type": "string", "pattern": "x"}}
      }
    }
  want: |
    choice?:
      .oneof:
      - +Str 1+
      - name: +Str
    negative?:
      .not: +Str /x/

- name: explicit-combinators-to-json-schema
  cmnd: sh -c 'bin/ysc -t schema.json -C - | fold -w 72'
  stdi: |
    choice:
      .oneof:
      - +Str 1+
      - name: +Str
    negative:
      .not: +Str =~"x"
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"o
    bject","properties":{"choice":{"oneOf":[{"type":"string","minLength":1},
    {"type":"object","properties":{"name":{"type":"string"}},"required":["na
    me"],"additionalProperties":false}]},"negative":{"not":{"type":"string",
    "pattern":"^x$"}}},"required":["choice","negative"],"additionalPropertie
    s":false}

- name: combinator-arity-errors
  cmnd: |
    sh -c '
      for value in "+One[]" "+One[+Str]" "+Any[+Str]" \
                   "+All[+Str]" "+Not[]"; do
        printf "x: %s\n" "$value" |
          bin/ysc -t yscj -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysc: +One requires at least two type references
    ysc: +One requires at least two type references
    ysc: +Any requires at least two type references
    ysc: +All requires at least two type references
    ysc: +Not requires at least one type reference

- name: reject-non-reference-combinator-member
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    bad: +One[+Str,foo]
  want: |
    ysc: +One accepts only type references

- name: list-suffixes-remain-distinct
  cmnd: sh -c 'bin/ysc -t yscj -C - | fold -w 72'
  stdi: |
    any[]: +Any
    exact: +Any[2]
  want: |
    {"any":{".base":"+Any",".list":true},"exact":{".base":"+Any",".list":tru
    e,".size":[2,2]}}

- name: base-plus-one-allof-roundtrip
  cmnd: |
    sh -c '
      bin/ysc -t yscj -C - |
        bin/ysc -f yscj -t schema.json -C - |
        fold -w 72
    '
  stdi: |
    value: +base +constraint
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"o
    bject","properties":{"value":{"$ref":"#\/$defs\/base","allOf":[{"$ref":"
    #\/$defs\/constraint"}]}},"required":["value"],"additionalProperties":fa
    lse}

- name: explicit-combinator-empty-error
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    bad:
      .anyof: []
  want: |
    ysc: yamlschema .anyof requires at least one type definition

- name: reject-pick-rename
  cmnd: |
    sh -c '
      printf "bad:\n  .pick:\n  - +Str\n  - +Int\n" |
        bin/ysc -t yscj -C - 2>&1 | sed -n 1p
      printf "bad: pick:x\n" |
        bin/ysc -t yscj -C - 2>&1 | sed -n 1p
    '
  want: |
    ysc: unsupported yamlschema directive: .pick; use .oneof
    ysc: unsupported yamlschema keyword: pick; use oneof

done:
