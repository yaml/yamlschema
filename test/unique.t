#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: unique
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "tags": {
          "type": "array",
          "items": {"type": "string"},
          "uniqueItems": true
        },
        "names": {
          "type": "array",
          "items": {"type": "string"},
          "uniqueItems": true,
          "minItems": 1
        },
        "triple": {
          "type": "array",
          "items": {"type": "integer"},
          "uniqueItems": true,
          "minItems": 3,
          "maxItems": 3
        },
        "subset": {
          "type": "array",
          "items": {"type": "string"},
          "uniqueItems": true,
          "minItems": 1,
          "maxItems": 3
        }
      },
      "required": ["tags", "names", "triple", "subset"]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    tags: +Str[!]
    names: +Str[!1+]
    triple: +Int[!3]
    subset: +Str[!1-3]

- name: redundant-array-keywords-normalize-away
  cmnd: bin/ysd -N -f jsc -
  stdi: |
    {
      "type": "array",
      "items": {},
      "uniqueItems": false,
      "minItems": 1,
      "default": {
        "items": {},
        "uniqueItems": false
      }
    }
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "array",
      "default": {
        "items": {},
        "uniqueItems": false
      },
      "minItems": 1
    }

- name: arbitrary-array-syntax
  cmnd: bin/ysd -t ysd -f jsc -
  stdi: |
    {
      "type": "object",
      "properties": {
        "enum": {
          "type": "array",
          "items": {},
          "uniqueItems": false,
          "minItems": 1
        },
        "unique": {
          "type": "array",
          "items": {},
          "uniqueItems": true,
          "minItems": 1
        }
      },
      "additionalProperties": false
    }
  want: |
    # Converted from JSON Schema
    enum?: +Any[1+]
    unique?: +Any[!1+]

- name: unconstrained-items-with-unevaluated-items-is-preserved
  cmnd: bin/ysd -N -f jsc -
  stdi: |
    {
      "type": "array",
      "items": {},
      "unevaluatedItems": false
    }
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "array",
      "items": {},
      "unevaluatedItems": false
    }

- name: arbitrary-nonempty-array-roundtrip
  cmnd: bin/ysd -R -f jsc -
  stdi: |
    {
      "type": "object",
      "properties": {
        "enum": {
          "type": "array",
          "items": {},
          "uniqueItems": false,
          "minItems": 1
        },
        "unique": {
          "type": "array",
          "items": {},
          "uniqueItems": true,
          "minItems": 1
        }
      },
      "additionalProperties": false
    }
  want: |
    OK

done:
