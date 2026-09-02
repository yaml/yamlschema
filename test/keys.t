#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: singleton-allof-anyof-imports-as-key-rule
  cmnd: bin/ysd -t ysd -
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
  cmnd: bin/ysd -t jsc -
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
          "required": [
            "harborAdminPassword"
          ],
          "properties": {
            "harborAdminPassword": {
              "type": "string",
              "minLength": 8
            }
          }
        },
        {
          "required": [
            "existingSecretAdminPassword"
          ],
          "properties": {
            "existingSecretAdminPassword": {
              "type": "string",
              "minLength": 1
            }
          }
        }
      ]
    }

- name: optional-branch-properties-and-multiple-rules
  cmnd: |
    sh -c '
      bin/ysd -t jsc -C - |
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
    [{"anyOf":[{"required":["first"],"properties":{"first":{"type":"string"}}},{"properties":{"second":{"type":"integer"}}}]},{"anyOf":[{"required":["third"],"properties":{"third":{"type":"boolean"}}},{"required":["fourth"],"properties":{"fourth":{"type":"null"}}}]}]

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
          bin/ysd -t ysdc - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysd: yamlschema .keys requires a non-empty sequence of rules
    ysd: yamlschema .keys requires a non-empty sequence of rules
    ysd: yamlschema .keys rules currently require exactly one .any entry
    ysd: yamlschema .keys .any requires at least two branches
    ysd: yamlschema .keys .any branches require property-to-type mappings
    ysd: yamlschema .keys .any branch keys must be property names

- name: singleton-allof-anyof-normalization-is-narrow
  cmnd: |
    sh -c '
      bin/ysd -N -f jsc - |
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
      bin/ysd -N -f jsc - |
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
  cmnd: sh -c 'bin/ysd -t jsc -C - 2>&1 >/dev/null'
  stdi: |
    .keys:
    - .any:
      - foo:
          .if: {}
      - bar: +Float
  want: |
    ysd: warning: unsupported JSON Schema keyword "if" at /anyOf/0/properties/foo/if
    ysd: warning: +Float at /anyOf/1/properties/bar exports as JSON Schema "number", which also accepts integers

- name: tracked-schema-roundtrip
  cmnd: sh -c 'bin/ysd -Rq -f jsc - && echo OK'
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
