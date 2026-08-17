#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: compact-combinator-expansion
  cmnd: sh -c 'bin/ysc -t yscj -C - | fold -w 72'
  stdi: |
    one: +One(+Str,+Int)
    any: +Any( +foo, +bar )
    all: +All(+foo,+bar)
    composed: +base +constraint +other
    not-one: +Not(+foo)
    not-many: +Not(+Str,+Int)
    namespaced: +Any(+net/port,+contact/email)
    values: +Any(+foo,+bar)[]
  want: |
    {"one":{".one":["+Str","+Int"]},"any":{".any":["+foo","+bar"]},"all":{".
    all":["+foo","+bar"]},"composed":{".type":"+base",".all":["+constraint",
    "+other"]},"not-one":{".not":"+foo"},"not-many":{".not":{".any":["+Str",
    "+Int"]}},"namespaced":{".any":["+net\/port","+contact\/email"]},"values
    ":{".type":"+Any[]",".any":["+foo","+bar"]}}

- name: compact-combinators-to-json-schema
  cmnd: bin/ysc -t schema.json -
  stdi: |
    one: +One(+Str,+Int)
    any: +Any(+foo,+bar)
    all: +All(+foo,+bar)
    composed: +base +constraint +other
    not: +Not(+Str,+Int)
    values: +Any(+foo,+bar)[]
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
            "type": [
              "string",
              "integer"
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
    # Converted from JSON Schema
    .open: true
    one?: +One(+Str,+Int)
    any?: +Any(+foo,+bar)
    all?: +All(+foo,+bar)
    not?: +Not(+Str,+Int)

- name: singleton-ref-allof-with-properties
  cmnd: bin/ysc -t ysd -
  stdi: |
    {
      "$defs": {
        "base": {
          "type": "object",
          "properties": {"shared": {"type": "string"}}
        }
      },
      "type": "object",
      "properties": {
        "component": {
          "type": "object",
          "description": "Component",
          "allOf": [{"$ref": "#/$defs/base"}],
          "properties": {"local": {"type": "integer"}}
        },
        "alias": {
          "allOf": [{"$ref": "#/$defs/base"}]
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true

    +base:
      shared?: +Str

    component?:
      .type: +base
      .desc: Component
      local?: +Int
    alias?: +base

- name: referenced-base-with-properties-to-json-schema
  cmnd: bin/ysc -f ysd -t jsc -C -
  stdi: |
    .open: true
    +base:
      shared?: +Str
    component?:
      .type: +base
      .desc: Component
      local?: +Int
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"component":{"description":"Component","type":"object","$ref":"#\/$defs\/base","properties":{"local":{"type":"integer"}}}},"additionalProperties":false,"$defs":{"base":{"type":"object","properties":{"shared":{"type":"string"}}}}}

- name: primitive-any-is-json-type-union
  cmnd: bin/ysc -t schema.json -C -
  stdi: |
    value: +Any(+Str,+Int)
    nullable: +Any(+Str,+Int)~
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"nullable":{"type":["string","integer","null"]},"value":{"type":["string","integer"]}},"required":["value","nullable"],"additionalProperties":false}

- name: json-type-union-to-compact-any
  cmnd: bin/ysc -t ysd.yaml -
  stdi: |
    {
      "properties": {
        "artifactPullAsyncFlushDuration": {
          "type": ["string", "integer"]
        },
        "nullable": {
          "type": ["string", "integer", "null"]
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    artifactPullAsyncFlushDuration?: +Any(+Str,+Int)
    nullable?: +Any(+Str,+Int)~

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
    # Converted from JSON Schema
    .open: true
    choice?:
      .one:
      - +Str 1+
      - name: +Str
    negative?:
      .not: +Str /x/

- name: explicit-combinators-to-json-schema
  cmnd: sh -c 'bin/ysc -t schema.json -C - | fold -w 72'
  stdi: |
    choice:
      .one:
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
      for value in "+One()" "+One(+Str)" "+Any(+Str)" \
                   "+All(+Str)" "+Not()"; do
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
    bad: +One(+Str,foo)
  want: |
    ysc: +One accepts only type references

- name: reject-square-bracket-combinators
  cmnd: |
    sh -c '
      for value in "+One[+Str,+Int]" "+Any[+Str,+Int]" \
                   "+All[+Str,+Int]" "+Not[+Str]"; do
        printf "x: %s\n" "$value" |
          bin/ysc -t yscj -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysc: unsupported compact combinator syntax: +One[+Str,+Int]; use +One(+Str,+Int)
    ysc: unsupported compact combinator syntax: +Any[+Str,+Int]; use +Any(+Str,+Int)
    ysc: unsupported compact combinator syntax: +All[+Str,+Int]; use +All(+Str,+Int)
    ysc: unsupported compact combinator syntax: +Not[+Str]; use +Not(+Str)

- name: list-suffixes-remain-distinct
  cmnd: sh -c 'bin/ysc -t yscj -C - | fold -w 72'
  stdi: |
    any: +Any[]
    exact: +Any[2]
  want: |
    {"any":"+Any[]","exact":{".type":"+Any[]",".size":[2,2]}}

- name: base-plus-one-all-roundtrip
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
      .any: []
  want: |
    ysc: yamlschema .any requires at least one type definition

- name: reject-pick-rename
  cmnd: |
    sh -c '
      printf "bad:\n  .pick:\n  - +Str\n  - +Int\n" |
        bin/ysc -t yscj -C - 2>&1 | sed -n 1p
      printf "bad: pick:x\n" |
        bin/ysc -t yscj -C - 2>&1 | sed -n 1p
    '
  want: |
    ysc: unsupported yamlschema directive: .pick; use .one
    ysc: unsupported yamlschema keyword: pick; use one

- name: reject-old-combinator-names
  cmnd: |
    sh -c '
      for pair in ".oneof .one" ".anyof .any" ".allof .all"; do
        set -- $pair
        printf "bad:\n  %s: []\n" "$1" |
          bin/ysc -t yscj -C - 2>&1 | sed -n 1p
      done
      for pair in "oneof one" "anyof any" "allof all"; do
        set -- $pair
        printf "bad: %s:x\n" "$1" |
          bin/ysc -t yscj -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysc: unsupported yamlschema directive: .oneof; use .one
    ysc: unsupported yamlschema directive: .anyof; use .any
    ysc: unsupported yamlschema directive: .allof; use .all
    ysc: unsupported yamlschema keyword: oneof; use one
    ysc: unsupported yamlschema keyword: anyof; use any
    ysc: unsupported yamlschema keyword: allof; use all

done:
