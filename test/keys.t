#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: singleton-allof-anyof-imports-as-key-rule
  cmnd: bin/ysc -t ysd -
  stdi: |
    {
      "type": "object",
      "properties": {
        "harborAdminPassword": {"type": "string"},
        "existingSecretAdminPassword": {"type": "string"}
      },
      "allOf": [
        {
          "anyOf": [
            {
              "properties": {
                "harborAdminPassword": {
                  "type": "string",
                  "minLength": 8
                }
              },
              "required": ["harborAdminPassword"]
            },
            {
              "properties": {
                "existingSecretAdminPassword": {
                  "type": "string",
                  "minLength": 1
                }
              },
              "required": ["existingSecretAdminPassword"]
            }
          ]
        }
      ]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    harborAdminPassword?: +Str
    existingSecretAdminPassword?: +Str
    .keys:
    - .any:
      - harborAdminPassword: +Str 8+
      - existingSecretAdminPassword: +Str 1+

- name: key-rule-exports-partial-mapping-constraints
  cmnd: bin/ysc -t jsc -
  stdi: |
    .open: true
    .keys:
    - .any:
      - harborAdminPassword: +Str 8+
      - existingSecretAdminPassword: +Str 1+
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "anyOf": [
        {
          "properties": {
            "harborAdminPassword": {
              "type": "string",
              "minLength": 8
            }
          },
          "required": [
            "harborAdminPassword"
          ]
        },
        {
          "properties": {
            "existingSecretAdminPassword": {
              "type": "string",
              "minLength": 1
            }
          },
          "required": [
            "existingSecretAdminPassword"
          ]
        }
      ]
    }

- name: optional-branch-properties-and-multiple-rules
  cmnd: |
    sh -c '
      bin/ysc -t jsc -C - |
        jq -c ".allOf"
    '
  stdi: |
    .keys:
    - .any:
      - first: +Str
      - second?: +Int
    - .any:
      - third: +Bool
      - fourth: +Null
  want: |
    [{"anyOf":[{"properties":{"first":{"type":"string"}},"required":["first"]},{"properties":{"second":{"type":"integer"}}}]},{"anyOf":[{"properties":{"third":{"type":"boolean"}},"required":["third"]},{"properties":{"fourth":{"type":"null"}},"required":["fourth"]}]}]

- name: key-rule-validation-errors
  cmnd: |
    sh -c '
      for input in \
        ".keys: nope" \
        ".keys: []" \
        ".keys:\n- .one: [foo, bar]" \
        ".keys:\n- .any: [{foo: +Str}]" \
        ".keys:\n- .any: [nope, {foo: +Str}]" \
        ".keys:\n- .any: [{.type: +Str}, {foo: +Str}]"; do
        printf "%b\n" "$input" |
          bin/ysc -t yscy - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysc: yamlschema .keys requires a non-empty sequence of rules
    ysc: yamlschema .keys requires a non-empty sequence of rules
    ysc: yamlschema .keys rules currently require exactly one .any entry
    ysc: yamlschema .keys .any requires at least two branches
    ysc: yamlschema .keys .any branches require property-to-type mappings
    ysc: yamlschema .keys .any branch keys must be property names

- name: singleton-allof-anyof-normalization-is-narrow
  cmnd: |
    sh -c '
      bin/ysc -N -f jsc - |
        jq -c "{anyOf: .anyOf, allOf: .allOf}"
    '
  stdi: |
    {
      "allOf": [
        {
          "anyOf": [{"type": "string"}, {"type": "integer"}]
        }
      ]
    }
  want: |
    {"anyOf":[{"type":"string"},{"type":"integer"}],"allOf":null}

- name: singleton-allof-anyof-with-sibling-stays-allof
  cmnd: |
    sh -c '
      bin/ysc -N -f jsc - |
        jq -c "{anyOf: .anyOf, allOf: .allOf}"
    '
  stdi: |
    {
      "allOf": [
        {
          "title": "A choice",
          "anyOf": [{"type": "string"}, {"type": "integer"}]
        }
      ]
    }
  want: |
    {"anyOf":null,"allOf":[{"title":"A choice","anyOf":[{"type":"string"},{"type":"integer"}]}]}

- name: key-rule-warning-paths
  cmnd: sh -c 'bin/ysc -t jsc -C - 2>&1 >/dev/null'
  stdi: |
    .keys:
    - .any:
      - foo:
          .if: {}
      - bar: +Float
  want: |
    ysc: warning: unsupported JSON Schema keyword "if" at /anyOf/0/properties/foo/if
    ysc: warning: +Float at /anyOf/1/properties/bar exports as JSON Schema "number", which also accepts integers

- name: tracked-schema-roundtrip
  cmnd: sh -c 'bin/ysc -Rq -f jsc - && echo OK'
  stdi: |
    {
      "type": "object",
      "properties": {
        "name": {"type": "string"}
      },
      "required": ["name"],
      "additionalProperties": false
    }
  want: |
    OK

done:
