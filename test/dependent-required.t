#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: import-compact-dependencies
  cmnd: bin/ysc -t ysd -
  stdi: |
    {
      "type": "object",
      "properties": {
        "first": {"type": "string"},
        "second": {"type": "integer"}
      },
      "dependentRequired": {
        "first": ["second", "third"],
        "second": []
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    first?: +Str :need(second,third)
    second?: +Int :need()

- name: export-compact-dependencies
  cmnd: |
    sh -c '
      bin/ysc -t jsc -C - |
        jq -c ".required, .dependentRequired, .additionalProperties"
    '
  stdi: |
    first: +Str :need(second,third)
    second?: +Int :need()
  want: |
    ["first"]
    {"first":["second","third"],"second":[]}
    false

- name: import-explicit-complex-dependency
  cmnd: bin/ysc -t ysd -
  stdi: |
    {
      "type": "object",
      "properties": {"first": {"type": "string"}},
      "dependentRequired": {"first": ["a b", "other"]}
    }
  want: |
    # Converted from JSON Schema
    .open: true
    first?:
      .type: +Str
      .need: [a b, other]

- name: export-explicit-complex-dependency
  cmnd: |
    sh -c '
      bin/ysc -t jsc -C - |
        jq -c ".dependentRequired"
    '
  stdi: |
    first?:
      .type: +Str
      .need: [a b, other]
  want: |
    {"first":["a b","other"]}

- name: nested-dependency-roundtrip
  cmnd: sh -c 'bin/ysc -Rq - && echo OK'
  stdi: |
    {
      "type": "object",
      "properties": {
        "nested": {
          "type": "object",
          "properties": {"trigger": {"type": "integer"}},
          "dependentRequired": {
            "trigger": ["a b", "undeclared-target"]
          }
        }
      },
      "additionalProperties": false
    }
  want: |
    OK

- name: address-roundtrip
  cmnd: sh -c 'bin/ysc -Rq www/src/examples/address.schema.json && echo OK'
  want: |
    OK

- name: reject-undeclared-trigger
  cmnd: |
    sh -c '
      bin/ysc -t ysd - 2>&1 |
        perl -ne "print if $. == 1"
      printf "%s\n" \
        "{\"type\":\"object\",\"dependentRequired\":{\"missing\":[]}}" |
        bin/ysc -t ysd - 2>&1 |
        perl -ne "print if $. == 1"
    '
  stdi: |
    {
      "type": "object",
      "properties": {"declared": {"type": "string"}},
      "dependentRequired": {"missing": ["declared"]}
    }
  want: |
    ysc: dependentRequired trigger has no property declaration: missing
    ysc: dependentRequired trigger has no property declaration: missing

- name: reject-invalid-json-dependencies
  cmnd: |
    sh -c '
      for value in true "[1]" "[\"same\",\"same\"]"; do
        printf "%s\n" \
          "{\"type\":\"object\",\"properties\":{\"key\":{}},"\
          "\"dependentRequired\":{\"key\":$value}}" |
          bin/ysc -t ysd - 2>&1 |
          perl -ne "print if $. == 1"
      done
    '
  want: |
    ysc: yamlschema .need requires a sequence of property names
    ysc: yamlschema .need property names must be strings
    ysc: yamlschema .need property names must be unique

- name: reject-invalid-ysd-dependencies
  cmnd: |
    sh -c '
      for value in true "[1]" "[same, same]"; do
        printf "key:\n  .type: +Str\n  .need: %s\n" "$value" |
          bin/ysc -t jsc -C - 2>&1 |
          perl -ne "print if $. == 1"
      done
    '
  want: |
    ysc: yamlschema .need requires a sequence of property names
    ysc: yamlschema .need property names must be strings
    ysc: yamlschema .need property names must be unique

- name: reject-malformed-and-misplaced-need
  cmnd: |
    sh -c '
      printf "key: +Str :need(a,,b)\n" |
        bin/ysc -t jsc -C - 2>&1 |
        perl -ne "print if $. == 1"
      printf "key: +Str need:a\n" |
        bin/ysc -t jsc -C - 2>&1 |
        perl -ne "print if $. == 1"
      printf ".need: [key]\n" |
        bin/ysc -t jsc -C - 2>&1 |
        perl -ne "print if $. == 1"
      printf "+Type:\n  .type: +Str\n  .need: [key]\n" |
        bin/ysc -t jsc -C - 2>&1 |
        perl -ne "print if $. == 1"
    '
  want: |
    ysc: invalid yamlschema need clause: :need(a,,b)
    ysc: unsupported yamlschema keyword: need; use :need(...)
    ysc: yamlschema .need is only valid on a property definition
    ysc: yamlschema .need is only valid on a property definition

done:
