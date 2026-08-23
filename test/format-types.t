#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: all-json-schema-formats-to-ysd
  cmnd: bin/ysd -f jsc -t ysd -
  stdi: |
    {
      "type": "object",
      "properties": {
        "date-time": {"type": "string", "format": "date-time"},
        "date": {"type": "string", "format": "date"},
        "time": {"type": "string", "format": "time"},
        "duration": {"type": "string", "format": "duration"},
        "email": {"type": "string", "format": "email"},
        "idn-email": {"type": "string", "format": "idn-email"},
        "hostname": {"type": "string", "format": "hostname"},
        "idn-hostname": {"type": "string", "format": "idn-hostname"},
        "ipv4": {"type": "string", "format": "ipv4"},
        "ipv6": {"type": "string", "format": "ipv6"},
        "uri": {"type": "string", "format": "uri"},
        "uri-reference": {"type": "string", "format": "uri-reference"},
        "iri": {"type": "string", "format": "iri"},
        "iri-reference": {"type": "string", "format": "iri-reference"},
        "uuid": {"type": "string", "format": "uuid"},
        "uri-template": {"type": "string", "format": "uri-template"},
        "json-pointer": {"type": "string", "format": "json-pointer"},
        "relative-json-pointer": {
          "type": "string",
          "format": "relative-json-pointer"
        },
        "regex": {"type": "string", "format": "regex"}
      },
      "additionalProperties": false
    }
  want: |
    # Converted from JSON Schema
    date-time?: +JSONSchema/date-time
    date?: +JSONSchema/date
    time?: +JSONSchema/time
    duration?: +JSONSchema/duration
    email?: +JSONSchema/email
    idn-email?: +JSONSchema/idn-email
    hostname?: +JSONSchema/hostname
    idn-hostname?: +JSONSchema/idn-hostname
    ipv4?: +JSONSchema/ipv4
    ipv6?: +JSONSchema/ipv6
    uri?: +JSONSchema/uri
    uri-reference?: +JSONSchema/uri-reference
    iri?: +JSONSchema/iri
    iri-reference?: +JSONSchema/iri-reference
    uuid?: +JSONSchema/uuid
    uri-template?: +JSONSchema/uri-template
    json-pointer?: +JSONSchema/json-pointer
    relative-json-pointer?: +JSONSchema/relative-json-pointer
    regex?: +JSONSchema/regex

- name: all-qualified-format-types-roundtrip
  cmnd: sh -c 'bin/ysd -f ysd -Rq - && echo OK'
  stdi: |
    date-time?: +JSONSchema/date-time
    date?: +JSONSchema/date
    time?: +JSONSchema/time
    duration?: +JSONSchema/duration
    email?: +JSONSchema/email
    idn-email?: +JSONSchema/idn-email
    hostname?: +JSONSchema/hostname
    idn-hostname?: +JSONSchema/idn-hostname
    ipv4?: +JSONSchema/ipv4
    ipv6?: +JSONSchema/ipv6
    uri?: +JSONSchema/uri
    uri-reference?: +JSONSchema/uri-reference
    iri?: +JSONSchema/iri
    iri-reference?: +JSONSchema/iri-reference
    uuid?: +JSONSchema/uuid
    uri-template?: +JSONSchema/uri-template
    json-pointer?: +JSONSchema/json-pointer
    relative-json-pointer?: +JSONSchema/relative-json-pointer
    regex?: +JSONSchema/regex
  want: |
    OK

- name: qualified-format-type-to-json-schema
  cmnd: bin/ysd -f ysd -t jsc -
  stdi: |
    dateOfBirth: +JSONSchema/date
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "dateOfBirth": {
          "type": "string",
          "format": "date"
        }
      },
      "required": [
        "dateOfBirth"
      ],
      "additionalProperties": false
    }

- name: nullable-qualified-format-type
  cmnd: bin/ysd -f ysd -t jsc -
  stdi: |
    completedAt?: +JSONSchema/date-time~
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "completedAt": {
          "type": [
            "string",
            "null"
          ],
          "format": "date-time"
        }
      },
      "additionalProperties": false
    }

- name: unknown-qualified-format-type-is-rejected
  cmnd: |
    sh -c '
      output=$(bin/ysd -f ysd -t jsc - 2>&1)
      status=$?
      test "$status" -eq 2
      printf "%s\n" "$output" | head -n 1
    '
  stdi: |
    value: +JSONSchema/not-a-format
  want: |
    ysd: unknown JSON Schema format type: +JSONSchema/not-a-format

- name: custom-json-format-stays-passthrough
  cmnd: sh -c 'bin/ysd -f jsc -t ysd - 2>/dev/null'
  stdi: |
    {
      "type": "object",
      "properties": {
        "value": {"type": "string", "format": "custom-value"}
      },
      "additionalProperties": false
    }
  want: |
    # Converted from JSON Schema
    value?:
      .type: +Str
      .format: custom-value

done:
