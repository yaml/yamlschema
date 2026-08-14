#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: compact-enums-use-comma-space
  cmnd: bin/ysc -t ysd -
  stdi: |
    {
      "properties": {
        "mode": {
          "type": "string",
          "enum": ["debug", "info", "warning", "error", "fatal"],
          "default": "info"
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    mode?: +Str [debug, =info, warning, error, fatal]

- name: overlong-enum-and-description-use-separate-clauses
  cmnd: bin/ysc -t ysd -
  stdi: |
    {
      "properties": {
        "mode": {
          "type": "string",
          "enum": [
            "debug mode", "info mode", "warning mode",
            "error mode", "fatal mode"
          ],
          "default": "info mode",
          "description": "Component logging mode."
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    mode?: +Str
      [debug mode, =info mode, warning mode, error mode, fatal mode]
      "Component logging mode."

- name: long-enum-wraps-only-after-commas
  cmnd: bin/ysc -t ysd -
  stdi: |
    {
      "properties": {
        "mode": {
          "type": "string",
          "enum": [
            "debug", "info", "warning", "error", "fatal",
            "extremely-long-alpha-setting",
            "extremely-long-beta-setting"
          ],
          "description": "Select the logging behavior used by every component in this deployment."
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    mode?: +Str
      [debug, info, warning, error, fatal, extremely-long-alpha-setting,
      extremely-long-beta-setting]
      "Select the logging behavior used by every component in this deployment."

- name: nested-description-wraps-at-physical-column-80
  cmnd: bin/ysc -t ysd -
  stdi: |
    {
      "properties": {
        "harborComponent": {
          "type": "object",
          "properties": {
            "config": {
              "type": "object",
              "additionalProperties": {},
              "description": "Primary component config. For env-driven components (core, exporter, trivy) it is flattened to env vars via toEnvVars. For file-driven components (registry, jobservice) it is the config file body passed through verbatim."
            }
          }
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    harborComponent?:
      config?: +Map{+Any}
        "Primary component config. For env-driven components (core, exporter, trivy)
        it is flattened to env vars via toEnvVars. For file-driven components
        (registry, jobservice) it is the config file body passed through verbatim."

- name: line-wrap-boundary-is-over-80
  cmnd: |
    sh -c '
      for width in 69 70; do
        description=$(printf "%0${width}d" 0 | tr 0 a)
        printf \
          "{\"properties\":{\"x\":{\"type\":\"string\",\"description\":\"%s\"}}}\n" \
          "$description" |
          bin/ysc -t ysd - |
          awk -v width="$width" "{print width, length(\$0)}"
      done
    '
  want: |
    69 28
    69 11
    69 80
    70 28
    70 11
    70 8
    70 74

- name: wrapped-description-preserves-escapes-and-spacing
  cmnd: |
    sh -c '
      set -eu
      tmp=$(mktemp -d)
      trap "rm -r \"$tmp\"" EXIT
      cat > "$tmp/in.schema.json"
      bin/ysc -t ysd "$tmp/in.schema.json" > "$tmp/out.ysd.yaml"
      cat "$tmp/out.ysd.yaml"
      bin/ysc -f ysd -t jsc -C "$tmp/out.ysd.yaml" |
        ys -e "say: IN:read:json/load.properties.escaped.description"
    '
  stdi: |
    {
      "properties": {
        "escaped": {
          "type": "string",
          "description": "this: that # the other foo\\ bar and  two spaces plus enough ordinary words to force wrapping safely"
        }
      }
    }
  want: |
    # Converted from JSON Schema
    .open: true
    escaped?: +Str
      "this:\ that \# the other foo\ bar and  two spaces plus enough ordinary words
      to force wrapping safely"
    this: that # the other foo\ bar and  two spaces plus enough ordinary words to force wrapping safely

- name: indivisible-enum-member-may-exceed-80
  cmnd: |
    sh -c '
      member=$(printf "%090d" 0 | tr 0 a)
      printf \
        "{\"properties\":{\"x\":{\"type\":\"string\",\"enum\":[\"%s\"]}}}\n" \
        "$member" |
        bin/ysc -t ysd - |
        awk "{print length(\$0)}"
    '
  want: |
    28
    11
    8
    94

- name: wrapped-enum-and-description-retain-schema-semantics
  cmnd: |
    sh -c '
      set -eu
      tmp=$(mktemp -d)
      trap "rm -r \"$tmp\"" EXIT
      cat > "$tmp/in.schema.json"
      bin/ysc -t ysd "$tmp/in.schema.json" > "$tmp/out.ysd.yaml"
      bin/ysc -f ysd -t jsc -C "$tmp/out.ysd.yaml" \
        > "$tmp/out.schema.json"
      ys -pe \
        "ARGS.0:read:json/load.properties.mode == ARGS.1:read:json/load.properties.mode" \
        -- "$tmp/in.schema.json" "$tmp/out.schema.json"
    '
  stdi: |
    {
      "properties": {
        "mode": {
          "type": "string",
          "enum": [
            "debug mode", "info mode", "warning mode",
            "error mode", "fatal mode"
          ],
          "default": "info mode",
          "description": "Component logging mode."
        }
      }
    }
  want: |
    true

done:
