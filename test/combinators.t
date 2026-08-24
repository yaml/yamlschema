#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: compact-combinator-expansion
  cmnd: sh -c 'bin/ysd -t ysdc.json -C - | fold -w 72'
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
  cmnd: bin/ysd -t schema.json -
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
  cmnd: bin/ysd -t ysd.yaml -
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
  cmnd: bin/ysd -t ysd -
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
  cmnd: bin/ysd -f ysd -t jsc -C -
  stdi: |
    .open: true
    +base:
      shared?: +Str
    component?:
      .type: +base
      .desc: Component
      local?: +Int
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"component":{"description":"Component","type":"object","$ref":"#\/$defs\/base","properties":{"local":{"type":"integer"}}}},"$defs":{"base":{"type":"object","properties":{"shared":{"type":"string"}}}}}

- name: primitive-any-is-json-type-union
  cmnd: bin/ysd -t schema.json -C -
  stdi: |
    value: +Any(+Str,+Int)
    nullable: +Any(+Str,+Int)~
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"value":{"type":["string","integer"]},"nullable":{"type":["string","integer","null"]}},"required":["value","nullable"],"additionalProperties":false}

- name: json-type-union-to-compact-any
  cmnd: bin/ysd -t ysd.yaml -
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
  cmnd: bin/ysd -t ysd.yaml -
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
  cmnd: sh -c 'bin/ysd -t schema.json -C - | fold -w 72'
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
          bin/ysd -t ysdc.json -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysd: +One requires at least two type references
    ysd: +One requires at least two type references
    ysd: +Any requires at least two type references
    ysd: +All requires at least two type references
    ysd: +Not requires at least one type reference

- name: reject-non-reference-combinator-member
  cmnd: |
    sh -c 'bin/ysd -t ysdc.json -C - 2>&1 | sed -n 1p'
  stdi: |
    bad: +One(+Str,foo)
  want: |
    ysd: +One accepts only type references

- name: reject-square-bracket-combinators
  cmnd: |
    sh -c '
      for value in "+One[+Str,+Int]" "+Any[+Str,+Int]" \
                   "+All[+Str,+Int]" "+Not[+Str]"; do
        printf "x: %s\n" "$value" |
          bin/ysd -t ysdc.json -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysd: unsupported compact combinator syntax: +One[+Str,+Int]; use +One(+Str,+Int)
    ysd: unsupported compact combinator syntax: +Any[+Str,+Int]; use +Any(+Str,+Int)
    ysd: unsupported compact combinator syntax: +All[+Str,+Int]; use +All(+Str,+Int)
    ysd: unsupported compact combinator syntax: +Not[+Str]; use +Not(+Str)

- name: list-suffixes-remain-distinct
  cmnd: sh -c 'bin/ysd -t ysdc.json -C - | fold -w 72'
  stdi: |
    any: +Any[]
    exact: +Any[2]
  want: |
    {"any":"+Any[]","exact":{".type":"+Any[]",".size":[2,2]}}

- name: base-plus-one-all-roundtrip
  cmnd: |
    sh -c '
      bin/ysd -t ysdc.json -C - |
        bin/ysd -f ysdc.json -t schema.json -C - |
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
    sh -c 'bin/ysd -t ysdc.json -C - 2>&1 | sed -n 1p'
  stdi: |
    bad:
      .any: []
  want: |
    ysd: yamlschema .any requires at least one type definition

- name: reject-pick-rename
  cmnd: |
    sh -c '
      printf "bad:\n  .pick:\n  - +Str\n  - +Int\n" |
        bin/ysd -t ysdc.json -C - 2>&1 | sed -n 1p
      printf "bad: pick:x\n" |
        bin/ysd -t ysdc.json -C - 2>&1 | sed -n 1p
    '
  want: |
    ysd: unsupported yamlschema directive: .pick; use .one
    ysd: unsupported yamlschema keyword: pick; use one

- name: reject-old-combinator-names
  cmnd: |
    sh -c '
      for pair in ".oneof .one" ".anyof .any" ".allof .all"; do
        set -- $pair
        printf "bad:\n  %s: []\n" "$1" |
          bin/ysd -t ysdc.json -C - 2>&1 | sed -n 1p
      done
      for pair in "oneof one" "anyof any" "allof all"; do
        set -- $pair
        printf "bad: %s:x\n" "$1" |
          bin/ysd -t ysdc.json -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysd: unsupported yamlschema directive: .oneof; use .one
    ysd: unsupported yamlschema directive: .anyof; use .any
    ysd: unsupported yamlschema directive: .allof; use .all
    ysd: unsupported yamlschema keyword: oneof; use one
    ysd: unsupported yamlschema keyword: anyof; use any
    ysd: unsupported yamlschema keyword: allof; use all

- name: object-property-combinators
  cmnd: bin/ysd -f jsc -t ysd -
  stdi: |
    {
      "type": "object",
      "properties": {
        "single": {
          "type": "object",
          "properties": {
            "package_pip": {"type": "string"}
          },
          "oneOf": [
            {"required": ["package_pip"]}
          ],
          "additionalProperties": false
        },
        "multi": {
          "type": "object",
          "properties": {
            "a": {"type": "string"},
            "b": {"type": "integer"}
          },
          "oneOf": [
            {"required": ["a"]},
            {"required": ["b"]}
          ],
          "additionalProperties": false
        },
        "annotated": {
          "type": "object",
          "properties": {
            "a": {"type": "string"}
          },
          "oneOf": [
            {"title": "Branch", "required": ["a"]}
          ],
          "additionalProperties": false
        }
      },
      "additionalProperties": false
    }
  want: |
    # Converted from JSON Schema
    single?:
      package_pip: +Str
    multi?:
      .one:
      - .required:
        - a
      - .required:
        - b
      a?: +Str
      b?: +Int
    annotated?:
      .one:
      - .title: Branch
        .required:
        - a
      a?: +Str

- name: normalize-single-required-one-of
  cmnd: bin/ysd -N -f jsc -
  stdi: |
    {
      "type": "object",
      "properties": {
        "package_pip": {"type": "string"}
      },
      "oneOf": [
        {"required": ["package_pip"]}
      ],
      "additionalProperties": false
    }
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "package_pip": {
          "type": "string"
        }
      },
      "required": [
        "package_pip"
      ],
      "additionalProperties": false
    }

done:
