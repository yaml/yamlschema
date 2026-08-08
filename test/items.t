#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: items
  cmnd: bin/ysc -t ysc.yaml -
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
    tags[]: +Str
    names[1+]: +Str
    triple[3]: +Int
    subset[1-3]: +Str

- name: described-array-of-one-of-items
  cmnd: bin/ysc -t ysc.yaml -
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
    imagePullSecrets?[]:
      .oneof:
      - +Str 1+
      - name: +Str 1+
      .desc: List of image pull secrets

- name: described-array-of-any-items
  cmnd: bin/ysc -t ysc.yaml -
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
    extraManifests?[]: +Any "Extra static manifests to deploy"
    extraTemplateManifests?[]: +Any "Extra templated manifests to deploy"

done:
