#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: metadata-roundtrip
  cmnd: |
    sh -c '
      set -eu
      d=$(mktemp -d)
      cat > "$d/in.schema.json"
      bin/ysc -t ysd.yaml "$d/in.schema.json" > "$d/out.ysd.yaml"
      bin/ysc -t schema.json "$d/out.ysd.yaml" > "$d/out.schema.json"
      ys -pe "ARGS.0:read:json/load == ARGS.1:read:json/load" \
        -- "$d/in.schema.json" "$d/out.schema.json"
    '
  stdi: |
    {
      "$id": "https://example.com/arrays.schema.json",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "title": "Arrays",
      "description": "Arrays of strings and objects",
      "type": "object",
      "properties": {
        "fruits": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "vegetables": {
          "type": "array",
          "items": {
            "$ref": "#/$defs/veggie"
          }
        }
      },
      "$defs": {
        "veggie": {
          "type": "object",
          "description": "A vegetable record.",
          "required": ["veggieName", "veggieLike"],
          "properties": {
            "veggieName": {
              "type": "string",
              "title": "Vegetable name",
              "description": "The name of the vegetable."
            },
            "veggieLike": {
              "type": "boolean",
              "description": "Do I like this vegetable?"
            }
          },
          "additionalProperties": false
        }
      },
      "additionalProperties": false
    }
  want: |
    true

- name: constraints-roundtrip
  cmnd: |
    sh -c '
      set -eu
      d=$(mktemp -d)
      cat > "$d/in.schema.json"
      bin/ysc -t ysd.yaml "$d/in.schema.json" > "$d/out.ysd.yaml"
      bin/ysc -t schema.json "$d/out.ysd.yaml" > "$d/out.schema.json"
      ys -pe "ARGS.0:read:json/load == ARGS.1:read:json/load" \
        -- "$d/in.schema.json" "$d/out.schema.json"
    '
  stdi: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "role": {"type": "string", "enum": ["admin", "user", "guest"]},
        "version": {"const": "v1"},
        "host": {"type": "string", "default": "localhost"},
        "port": {"type": "integer", "minimum": 1, "maximum": 65535},
        "tags": {
          "type": "array",
          "items": {"type": "string"},
          "uniqueItems": true,
          "minItems": 1,
          "maxItems": 3
        },
        "anything": {"type": "array"}
      },
      "required": ["role", "version", "host", "port", "tags", "anything"],
      "additionalProperties": false
    }
  want: |
    true

done:
