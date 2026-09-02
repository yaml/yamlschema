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
    date-time?: +JSON-Schema/date-time
    date?: +JSON-Schema/date
    time?: +JSON-Schema/time
    duration?: +JSON-Schema/duration
    email?: +JSON-Schema/email
    idn-email?: +JSON-Schema/idn-email
    hostname?: +JSON-Schema/hostname
    idn-hostname?: +JSON-Schema/idn-hostname
    ipv4?: +JSON-Schema/ipv4
    ipv6?: +JSON-Schema/ipv6
    uri?: +JSON-Schema/uri
    uri-reference?: +JSON-Schema/uri-reference
    iri?: +JSON-Schema/iri
    iri-reference?: +JSON-Schema/iri-reference
    uuid?: +JSON-Schema/uuid
    uri-template?: +JSON-Schema/uri-template
    json-pointer?: +JSON-Schema/json-pointer
    relative-json-pointer?: +JSON-Schema/relative-json-pointer
    regex?: +JSON-Schema/regex

- name: all-qualified-format-types-roundtrip
  cmnd: sh -c 'bin/ysd -f ysd -Rq - && echo OK'
  stdi: |
    date-time?: +JSON-Schema/date-time
    date?: +JSON-Schema/date
    time?: +JSON-Schema/time
    duration?: +JSON-Schema/duration
    email?: +JSON-Schema/email
    idn-email?: +JSON-Schema/idn-email
    hostname?: +JSON-Schema/hostname
    idn-hostname?: +JSON-Schema/idn-hostname
    ipv4?: +JSON-Schema/ipv4
    ipv6?: +JSON-Schema/ipv6
    uri?: +JSON-Schema/uri
    uri-reference?: +JSON-Schema/uri-reference
    iri?: +JSON-Schema/iri
    iri-reference?: +JSON-Schema/iri-reference
    uuid?: +JSON-Schema/uuid
    uri-template?: +JSON-Schema/uri-template
    json-pointer?: +JSON-Schema/json-pointer
    relative-json-pointer?: +JSON-Schema/relative-json-pointer
    regex?: +JSON-Schema/regex
  want: |
    OK

- name: qualified-format-type-to-json-schema
  cmnd: bin/ysd -f ysd -t jsc -
  stdi: |
    dateOfBirth: +JSON-Schema/date
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "dateOfBirth"
      ],
      "properties": {
        "dateOfBirth": {
          "type": "string",
          "format": "date"
        }
      }
    }

- name: nullable-qualified-format-type
  cmnd: bin/ysd -f ysd -t jsc -
  stdi: |
    completedAt?: +JSON-Schema/date-time~
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "completedAt": {
          "type": [
            "string",
            "null"
          ],
          "format": "date-time"
        }
      }
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
    value: +JSON-Schema/not-a-format
  want: |
    ysd: unknown JSON Schema format type: +JSON-Schema/not-a-format

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
