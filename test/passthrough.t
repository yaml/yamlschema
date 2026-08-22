#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: json-schema-passthrough-warnings-and-ysd-data
  cmnd: sh -c 'bin/ysc -f jsc -t ysd - 2>&1'
  stdi: |
    {
      "type": "object",
      "properties": {
        "price": {
          "type": "number",
          "multipleOf": 0.5,
          "exclusiveMinimum": 0
        },
        "choice": {
          "if": {
            "properties": {
              "kind": {"format": "uuid"}
            }
          },
          "then": {"required": ["value"]}
        }
      },
      "additionalProperties": false
    }
  want: |
    ysc: warning: unsupported JSON Schema keyword "multipleOf" at /properties/price/multipleOf
    ysc: warning: unsupported JSON Schema keyword "exclusiveMinimum" at /properties/price/exclusiveMinimum
    ysc: warning: unsupported JSON Schema keyword "if" at /properties/choice/if
    ysc: warning: unsupported JSON Schema keyword "format" at /properties/choice/if/properties/kind/format
    ysc: warning: unsupported JSON Schema keyword "then" at /properties/choice/then
    # Converted from JSON Schema
    price?:
      .type: +Num
      .multipleOf: 0.5
      .exclusiveMinimum: 0
    choice?:
      .if:
        properties:
          kind:
            format: uuid
      .then:
        required:
        - value

- name: json-schema-to-ysc-preserves-passthrough-without-yaml-reload
  cmnd: sh -c 'bin/ysc -f jsc -t yscj -C - 2>&1'
  stdi: |
    {
      "type": "object",
      "properties": {
        "price": {"type": "number", "multipleOf": 0.5}
      },
      "additionalProperties": false
    }
  want: |
    ysc: warning: unsupported JSON Schema keyword "multipleOf" at /properties/price/multipleOf
    {"price?":{".type":"+Num",".multipleOf":0.5}}

- name: passthrough-roundtrip-from-expanded-yaml
  cmnd: sh -c 'bin/ysc -f yscy -t jsc -C - 2>&1'
  stdi: |
    price?:
      .type: +Num
      .multipleOf: 0.5
      .exclusiveMinimum: 0
    choice?:
      .if:
        properties:
          kind:
            format: uuid
      .then:
        required: [value]
  want: |
    ysc: warning: unsupported JSON Schema keyword "multipleOf" at /properties/price/multipleOf
    ysc: warning: unsupported JSON Schema keyword "exclusiveMinimum" at /properties/price/exclusiveMinimum
    ysc: warning: unsupported JSON Schema keyword "if" at /properties/choice/if
    ysc: warning: unsupported JSON Schema keyword "format" at /properties/choice/if/properties/kind/format
    ysc: warning: unsupported JSON Schema keyword "then" at /properties/choice/then
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","properties":{"price":{"type":"number","exclusiveMinimum":0,"multipleOf":0.5},"choice":{"if":{"properties":{"kind":{"format":"uuid"}}},"then":{"required":["value"]}}},"additionalProperties":false}

- name: passthrough-array-and-item-keywords-stay-at-their-levels
  cmnd: |
    sh -c '
      set -eu
      tmp=$(mktemp -d)
      trap "rm -r \"$tmp\"" EXIT
      cat > "$tmp/in.schema.json"
      bin/ysc -f jsc -t yscy "$tmp/in.schema.json" \
        > "$tmp/out.ysc.yaml" 2> "$tmp/import.warn"
      bin/ysc -f yscy -t jsc -C "$tmp/out.ysc.yaml" \
        > "$tmp/out.schema.json" 2> "$tmp/export.warn"
      cat "$tmp/import.warn"
      cat "$tmp/out.ysc.yaml"
      cat "$tmp/export.warn"
      ys -pe "ARGS.0:read:json/load == select-keys( \
        ARGS.1:read:json/load ARGS.0:read:json/load:keys)" \
        -- "$tmp/in.schema.json" "$tmp/out.schema.json"
    '
  stdi: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "emails": {
          "type": "array",
          "items": {"type": "string", "format": "email"},
          "contains": {"type": "string"},
          "minContains": 1
        }
      },
      "additionalProperties": false
    }
  want: |
    ysc: warning: unsupported JSON Schema keyword "format" at /properties/emails/items/format
    ysc: warning: unsupported JSON Schema keyword "contains" at /properties/emails/contains
    ysc: warning: unsupported JSON Schema keyword "minContains" at /properties/emails/minContains
    emails?:
      .type: +Any[]
      .item:
        .type: +Str
        .format: email
      .contains:
        type: string
      .minContains: 1
    ysc: warning: unsupported JSON Schema keyword "format" at /properties/emails/items/format
    ysc: warning: unsupported JSON Schema keyword "contains" at /properties/emails/contains
    ysc: warning: unsupported JSON Schema keyword "minContains" at /properties/emails/minContains
    true

- name: passthrough-warning-paths-escape-json-pointer-and-repeat
  cmnd: sh -c 'bin/ysc -f jsc -t ysd - 2>&1'
  stdi: |
    {
      "type": "object",
      "properties": {
        "a/b~c": {"multipleOf": 2},
        "other": {"multipleOf": 3}
      },
      "additionalProperties": false
    }
  want: |
    ysc: warning: unsupported JSON Schema keyword "multipleOf" at /properties/a~1b~0c/multipleOf
    ysc: warning: unsupported JSON Schema keyword "multipleOf" at /properties/other/multipleOf
    # Converted from JSON Schema
    a/b~c?:
      .multipleOf: 2
    other?:
      .multipleOf: 3

- name: unknown-dotted-directive-is-still-an-error
  cmnd: |
    sh -c '
      output=$(printf "field:\n  .formt: email\n" |
        bin/ysc -f ysd -t yscy - 2>&1)
      status=$?
      test "$status" -eq 2
      printf "%s\n" "$output" | sed -n 1p
    '
  want: |
    ysc: unsupported yamlschema directive: .formt

done:
