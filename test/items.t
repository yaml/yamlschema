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
      .type: +Any[]
      .one:
      - +Str 1+
      - name: +Str 1+
      .desc: List of image pull secrets

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
    extraManifests?: +Any[] "Extra static manifests to deploy"
    extraTemplateManifests?: +Any[] "Extra templated manifests to deploy"

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
    dates?: +JSONSchema/date[$] "One date or several dates"
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
      .name: values
      .type: +Str[$]
      .init: x
      .title: Values
      .desc: One or many

done:
