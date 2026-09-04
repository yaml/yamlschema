#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: items
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "tags":    {"type": "array", "items": {"type": "string"}},
        "names": {
          "type": "array", "items": {"type": "string"}, "minItems": 1
        },
        "triple": {
          "type": "array", "items": {"type": "integer"},
          "minItems": 3, "maxItems": 3
        },
        "subset": {
          "type": "array", "items": {"type": "string"},
          "minItems": 1, "maxItems": 3
        }
      },
      "required": ["tags", "names", "triple", "subset"]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    tags: +Str[]
    names: +Str[1+]
    triple: +Int[3]
    subset: +Str[1-3]

- name: described-array-of-one-of-items
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "imagePullSecrets": {
          "type": "array",
          "description": "List of image pull secrets",
          "items": {
            "oneOf": [
              {"type": "string", "minLength": 1},
              {
                "type": "object",
                "properties": {
                  "name": {"type": "string", "minLength": 1}
                },
                "required": ["name"]
              }
            ]
          }
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    imagePullSecrets?:
      --: List of image pull secrets
      .one[]:
      - +Str 1+
      - name: +Str 1+

- name: described-array-of-any-items
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "extraManifests": {
          "type": "array",
          "description": "Extra static manifests to deploy"
        },
        "extraTemplateManifests": {
          "type": "array",
          "description": "Extra templated manifests to deploy"
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    extraManifests?: +Any[] --"Extra static manifests to deploy"
    extraTemplateManifests?: +Any[] --"Extra templated manifests to deploy"

- name: legacy-tuple-items
  cmnd: sh -c 'bin/ysd -f jsc -t ysd - 2>/dev/null'
  stdi: |
    {
      "$schema": "http://json-schema.org/draft-04/schema#",
      "type": "object",
      "properties": {
        "openTuple": {
          "type": "array",
          "items": [{"type": "string"}]
        },
        "closedTuple": {
          "type": "array",
          "items": [{"type": "integer"}, {"type": "string"}],
          "additionalItems": false
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    openTuple?: +Tup{+Str?,+Any...}
    closedTuple?: +Tup{+Int?,+Str?}

- name: native-tuple-types
  cmnd: bin/ysd -t jsc -Y -
  stdi: |
    pair: +Tup{+Str,+Num}
    optional: +Tup{+Str,+Num?}
    open: +Tup{+Str?,+Any...}
    rest: +Tup{+Str,+Num...}
  want: |
    $schema: https://json-schema.org/draft/2020-12/schema
    type: object
    additionalProperties: false
    required:
    - pair
    - optional
    - open
    - rest
    properties:
      pair:
        type: array
        minItems: 2
        items: false
        prefixItems:
        - type: string
        - type: number
      optional:
        type: array
        minItems: 1
        items: false
        prefixItems:
        - type: string
        - type: number
      open:
        type: array
        prefixItems:
        - type: string
      rest:
        type: array
        minItems: 1
        items:
          type: number
        prefixItems:
        - type: string

- name: modern-tuple-import
  cmnd: bin/ysd -f jsc -t ysd -
  stdi: |
    {
      "type": "object",
      "properties": {
        "open": {
          "type": "array",
          "prefixItems": [{"type": "string"}]
        },
        "bounded": {
          "type": "array",
          "prefixItems": [{"type": "string"}],
          "items": {"type": "number"},
          "minItems": 3,
          "maxItems": 5
        },
        "annotated": {
          "type": "array",
          "prefixItems": [{"type": "string"}],
          "title": "Value",
          "uniqueItems": true
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    open?: +Tup{+Str?,+Any...}
    bounded?: +Tup{+Str,+Num...} 3-5
    annotated?:
      .type: +Tup{+Str?,+Any...}
      .uniq: true
      .title: Value

- name: tuple-list-suffixes
  cmnd: bin/ysd -t ysdc -Y -
  stdi: |
    list: +Tup{+Str,+Num}[]
    solo: +Tup{+Str,+Num}[$]
    nullable: +Tup{+Str,+Num?}~
    nested: +Tup{+Tup{+Str},+Map{+Any}}
  want: |
    list:
      .list: +Tup{+Str,+Num}
    solo:
      .list: +Tup{+Str,+Num}
      .solo: true
    nullable:
      .type: +Tup{+Str,+Num?}
      .null: true
    nested: +Tup{+Tup{+Str},+Map{+Any}}

- name: native-tuples-roundtrip
  cmnd: sh -c 'bin/ysd -Rq -f ysd - && echo OK'
  stdi: |
    pair: +Tup{+Str,+Num}
    optional: +Tup{+Str,+Num?}
    open: +Tup{+Str?,+Any...}
    rest: +Tup{+Str,+Num...}
    list: +Tup{+Str,+Num}[]
    solo: +Tup{+Str,+Num}[$]
  want: |
    OK

- name: invalid-tuple-members
  cmnd: |
    sh -c '
      for value in \
        "+Tup{+Str?,+Num}" \
        "+Tup{+Str...,+Num}" \
        "+Tup{+Str...,+Num...}" \
        "+Tup{+Str?...}" \
        "+Tup{+Str,,+Num}"; do
        printf "x: %s\n" "$value" |
          bin/ysd -t ysdc -J -C - 2>&1 |
          perl -ne "print if /^ysd:/"
      done
    '
  want: |
    ysd: required tuple member cannot follow an optional member
    ysd: repeating tuple member must be last
    ysd: repeating tuple member must be last
    ysd: repeating tuple member cannot be optional
    ysd: tuple type contains an empty member

- name: scalar-or-list-any-of
  cmnd: bin/ysd -f jsc -t ysd -
  stdi: |
    {
      "$defs": {"thing": {"type": "string"}},
      "type": "object",
      "properties": {
        "python": {
          "anyOf": [
            {"type": "string"},
            {"type": "array", "items": {"type": "string"}}
          ]
        },
        "ids": {
          "anyOf": [
            {
              "type": "array",
              "items": {"type": "integer"},
              "minItems": 1,
              "uniqueItems": true
            },
            {"type": "integer"}
          ]
        },
        "dates": {
          "description": "One date or several dates",
          "anyOf": [
            {"type": "string", "format": "date"},
            {
              "type": "array",
              "items": {"type": "string", "format": "date"}
            }
          ]
        },
        "things": {
          "anyOf": [
            {"$ref": "#/$defs/thing"},
            {
              "type": "array",
              "items": {"$ref": "#/$defs/thing"}
            }
          ]
        },
        "mismatch": {
          "anyOf": [
            {"type": "string"},
            {"type": "array", "items": {"type": "integer"}}
          ]
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true

    +thing: +Str

    python?: +Str[$]
    ids?: +Int[$!1+]
    dates?: +JSON-Schema/date[$] --"One date or several dates"
    things?: +thing[$]
    mismatch?:
      .any:
      - +Str
      - +Int[]

- name: annotated-scalar-or-list
  cmnd: bin/ysd -f jsc -t ysd -
  stdi: |
    {
      "type": "object",
      "properties": {
        "value": {
          "$anchor": "values",
          "title": "Values",
          "description": "One or many",
          "default": "x",
          "anyOf": [
            {"type": "string"},
            {"type": "array", "items": {"type": "string"}}
          ]
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    value?:
      --: One or many
      .name: values
      .type: +Str[$]
      .init: x
      .title: Values

done:
