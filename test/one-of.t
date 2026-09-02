#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: one-of-to-one
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "properties": {
        "auth": {
          "oneOf": [
            {
              "type": "object",
              "properties": {
                "token": {"type": "string"}
              },
              "required": ["token"]
            },
            {
              "type": "object",
              "properties": {
                "api_key": {"type": "string"}
              },
              "required": ["api_key"]
            }
          ]
        }
      },
      "required": ["auth"]
    }
  want: |
    # Converted from JSON Schema
    .open: true
    auth:
      .one:
      - token: +Str
      - api_key: +Str

- name: root-one-to-json-schema
  cmnd: bin/ysd -t jsc -
  stdi: |
    .ysid: https://example.com/device.ysd.yaml
    .open: true
    deviceType: +Str
    .one:
    - .xref: https://example.com/smartphone.schema.json
      deviceType?:
        .const: smartphone
    - .xref: https://example.com/laptop.schema.json
      deviceType?:
        .const: laptop
  want: |
    {
      "$id": "https://example.com/device.schema.json",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "required": [
        "deviceType"
      ],
      "oneOf": [
        {
          "$ref": "https://example.com/smartphone.schema.json",
          "properties": {
            "deviceType": {
              "const": "smartphone"
            }
          }
        },
        {
          "$ref": "https://example.com/laptop.schema.json",
          "properties": {
            "deviceType": {
              "const": "laptop"
            }
          }
        }
      ],
      "properties": {
        "deviceType": {
          "type": "string"
        }
      }
    }

- name: root-one-from-json-schema
  cmnd: bin/ysd -t ysd -
  stdi: |
    {
      "$id": "https://example.com/device.schema.json",
      "type": "object",
      "properties": {
        "deviceType": {"type": "string"}
      },
      "required": ["deviceType"],
      "oneOf": [
        {
          "$ref": "https://example.com/smartphone.schema.json",
          "properties": {
            "deviceType": {"const": "smartphone"}
          }
        },
        {
          "$ref": "https://example.com/laptop.schema.json",
          "properties": {
            "deviceType": {"const": "laptop"}
          }
        }
      ]
    }
  want: |
    # Converted from JSON Schema
    .ysid: https://example.com/device.ysd.yaml
    .open: true
    deviceType: +Str
    .one:
    - .xref: https://example.com/smartphone.schema.json
      deviceType?: +Str ==smartphone
    - .xref: https://example.com/laptop.schema.json
      deviceType?: +Str ==laptop

- name: root-one-roundtrip
  cmnd: sh -c 'bin/ysd -Rq - && echo OK'
  stdi: |
    {
      "type": "object",
      "properties": {
        "deviceType": {"type": "string"}
      },
      "required": ["deviceType"],
      "oneOf": [
        {
          "$ref": "https://example.com/smartphone.schema.json",
          "properties": {
            "deviceType": {"const": "smartphone"}
          }
        },
        {
          "$ref": "https://example.com/laptop.schema.json",
          "properties": {
            "deviceType": {"const": "laptop"}
          }
        }
      ]
    }
  want: |
    OK

done:
