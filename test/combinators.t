#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: compact-combinator-expansion
  cmnd: sh -c 'bin/ysd -t ysdc -J -C - | fold -w 72'
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
    ":{".list":{".any":["+foo","+bar"]}}}

- name: compact-combinators-to-json-schema
  cmnd: bin/ysd -t jsc -
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
      "additionalProperties": false,
      "required": [
        "one",
        "any",
        "all",
        "composed",
        "not",
        "values"
      ],
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
      }
    }

- name: list-combinator-directives
  cmnd: bin/ysd -t ysdc -Y -
  stdi: |
    one:
      .one[]:
      - +Str
      - +Int
    any:
      .any[1-3,!]:
      - +Str
      - +Int
    all:
      .all[$]:
      - +foo
      - +bar
    not:
      .not[]: +Str
  want: |
    one:
      .list:
        .one:
        - +Str
        - +Int
    any:
      .list:
        .any:
        - +Str
        - +Int
      .size: [1, 3]
      .uniq: true
    all:
      .list:
        .all:
        - +foo
        - +bar
      .solo: true
    not:
      .list:
        .not: +Str

- name: json-schema-to-compact-combinators
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "one": {"oneOf": [{"type": "string"}, {"type": "integer"}]},
        "any": {"anyOf": [{"$ref": "#/$defs/foo"},
                            {"$ref": "#/$defs/bar"}]},
        "all": {"allOf": [{"$ref": "#/$defs/foo"},
                            {"$ref": "#/$defs/bar"}]},
        "not": {"not": {"anyOf": [{"type": "string"},
                                      {"type": "integer"}]}},
        "machine": {
          "oneOf": [
            {"type": "string"},
            {
              "type": "array",
              "prefixItems": [{"type": "string"}]
            }
          ]
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    one?: +One(+Str,+Int)
    any?: +Any(+foo,+bar)
    all?: +All(+foo,+bar)
    not?: +Not(+Str,+Int)
    machine?: +One(+Str,+Tup{+Str?,+Any...})

- name: tuple-combinator-roundtrip
  cmnd: sh -c 'bin/ysd -Rq -f ysd - && echo OK'
  stdi: |
    machine?: +One(+Str,+Tup{+Str?,+Any...})
  want: |
    OK

- name: annotated-tuple-combinator-stays-block
  cmnd: bin/ysd -f jsc -t ysd -
  stdi: |
    {
      "properties": {
        "choice": {
          "oneOf": [
            {"type": "string"},
            {
              "type": "array",
              "prefixItems": [{"type": "string"}],
              "description": "Tuple"
            }
          ]
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    choice?:
      .one:
      - +Str
      - +Tup{+Str?,+Any...} --"Tuple"

- name: invalid-tuple-combinator-member
  cmnd: |
    sh -c 'bin/ysd -f ysd -t ysdc - 2>&1 |
      perl -ne "print if /^ysd:/"'
  stdi: |
    bad: +One(+Str,+Tup{+Str?,+Num})
  want: |
    ysd: required tuple member cannot follow an optional member

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
      --: Component
      .type: +base
      local?: +Int
    alias?: +base

- name: uppercase-singleton-ref-allof-with-properties
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "$schema": "http://json-schema.org/draft-04/schema#",
      "definitions": {
        "Base": {
          "type": "object"
        }
      },
      "type": "object",
      "properties": {
        "value": {
          "type": "object",
          "allOf": [
            {"$ref": "#/definitions/Base"}
          ],
          "properties": {
            "x": {"type": "string"}
          }
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true

    +Base: +Map{}

    value?:
      .xref: '#/definitions/Base'
      x?: +Str

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
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","$defs":{"base":{"type":"object","properties":{"shared":{"type":"string"}}}},"properties":{"component":{"description":"Component","type":"object","$ref":"#\/$defs\/base","properties":{"local":{"type":"integer"}}}}}

- name: primitive-any-is-json-type-union
  cmnd: bin/ysd -t jsc -C -
  stdi: |
    value: +Any(+Str,+Int)
    nullable: +Any(+Str,+Int)~
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":false,"required":["value","nullable"],"properties":{"value":{"type":["string","integer"]},"nullable":{"type":["string","integer","null"]}}}

- name: json-type-union-to-compact-any
  cmnd: bin/ysd -t ysd -
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
  cmnd: bin/ysd -t ysd -
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
      .not: +Str ~~"x"

- name: explicit-combinators-to-json-schema
  cmnd: sh -c 'bin/ysd -t jsc -C - | fold -w 72'
  stdi: |
    choice:
      .one:
      - +Str 1+
      - name: +Str
    negative:
      .not: +Str ~"x"
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"o
    bject","additionalProperties":false,"required":["choice","negative"],"pr
    operties":{"choice":{"oneOf":[{"type":"string","minLength":1},{"type":"o
    bject","additionalProperties":false,"required":["name"],"properties":{"n
    ame":{"type":"string"}}}]},"negative":{"not":{"type":"string","pattern":
    "^x$"}}}}

- name: combinator-arity-errors
  cmnd: |
    sh -c '
      for value in "+One()" "+One(+Str)" "+Any(+Str)" \
                   "+All(+Str)" "+Not()"; do
        printf "x: %s\n" "$value" |
          bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p
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
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
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
          bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysd: unsupported compact combinator syntax: +One[+Str,+Int]; use +One(+Str,+Int)
    ysd: unsupported compact combinator syntax: +Any[+Str,+Int]; use +Any(+Str,+Int)
    ysd: unsupported compact combinator syntax: +All[+Str,+Int]; use +All(+Str,+Int)
    ysd: unsupported compact combinator syntax: +Not[+Str]; use +Not(+Str)

- name: list-suffixes-remain-distinct
  cmnd: sh -c 'bin/ysd -t ysdc -J -C - | fold -w 72'
  stdi: |
    any: +Any[]
    exact: +Any[2]
  want: |
    {"any":{".list":"+Any"},"exact":{".list":"+Any",".size":[2,2]}}

- name: base-plus-one-all-roundtrip
  cmnd: |
    sh -c '
      bin/ysd -t ysdc -J -C - |
        bin/ysd -f ysdc -t jsc -C - |
        fold -w 72
    '
  stdi: |
    value: +base +constraint
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"o
    bject","additionalProperties":false,"required":["value"],"properties":{"
    value":{"$ref":"#\/$defs\/base","allOf":[{"$ref":"#\/$defs\/constraint"}
    ]}}}

- name: explicit-combinator-empty-error
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    bad:
      .any: []
  want: |
    ysd: yamlschema .any requires at least one type definition

- name: reject-pick-rename
  cmnd: |
    sh -c '
      printf "bad:\n  .pick:\n  - +Str\n  - +Int\n" |
        bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p
      printf "bad: pick:x\n" |
        bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p
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
          bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p
      done
      for pair in "oneof one" "anyof any" "allof all"; do
        set -- $pair
        printf "bad: %s:x\n" "$1" |
          bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p
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
      "additionalProperties": false,
      "required": [
        "package_pip"
      ],
      "properties": {
        "package_pip": {
          "type": "string"
        }
      }
    }

done:
