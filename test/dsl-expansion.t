#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: composed-and-hybrid-equivalence
  cmnd: bin/ysc -t yscj -
  stdi: |
    succinct: +Str[] /a.*b/ 10-20
    hybrid:
      .base: +Str[] /a.*b/ 10-20
      .titl: The "Good" Parts
  want: |
    {
      "succinct": {
        ".base": "+Str",
        ".list": true,
        ".like": "a.*b",
        ".size": [
          10,
          20
        ]
      },
      "hybrid": {
        ".base": "+Str",
        ".list": true,
        ".like": "a.*b",
        ".size": [
          10,
          20
        ],
        ".titl": "The \"Good\" Parts"
      }
    }

- name: inferred-types-and-only
  cmnd: bin/ysc -t yscj -
  stdi: |
    pattern: /a.*b/
    numbers: 1|2|3
    forced: +Str 1|2
    ratio: 0.5..1
    constant: User
    object:
      child?: +Bool
  want: |
    {
      "pattern": {
        ".base": "+Str",
        ".like": "a.*b"
      },
      "numbers": {
        ".base": "+Int",
        ".enum": [
          1,
          2,
          3
        ]
      },
      "forced": {
        ".base": "+Str",
        ".enum": [
          "1",
          "2"
        ]
      },
      "ratio": {
        ".base": "+Float",
        ".mini": 0.5,
        ".maxi": 1
      },
      "constant": {
        ".base": "+Str",
        ".only": "User"
      },
      "object": {
        ".base": "+Map",
        "child?": {
          ".base": "+Bool"
        }
      }
    }

- name: list-size-forms
  cmnd: bin/ysc -t yscj -
  stdi: |
    key?[!1+]: +Str
    value?: +Str[$|0-3]
    alias?: +Str[+]
    exact?: +Map 10
  want: |
    {
      "key?": {
        ".base": "+Str",
        ".list": true,
        ".size": [
          1
        ],
        ".uniq": true
      },
      "value?": {
        ".base": "+Str",
        ".list": true,
        ".size": [
          0,
          3
        ],
        ".solo": true
      },
      "alias?": {
        ".base": "+Str",
        ".list": true,
        ".size": [
          1
        ]
      },
      "exact?": {
        ".base": "+Map",
        ".size": [
          10,
          10
        ]
      }
    }

- name: nullable-default-title-description
  cmnd: bin/ysc -t yscj -
  stdi: |
    flag?: +Bool~ =false titl:"Flag" "Whether it is enabled"
    label?: +Str ="pretty good"
  want: |
    {
      "flag?": {
        ".base": "+Bool",
        ".null": true,
        ".init": false,
        ".titl": "Flag",
        ".desc": "Whether it is enabled"
      },
      "label?": {
        ".base": "+Str",
        ".init": "pretty good"
      }
    }

- name: explicit-order-is-declarative
  cmnd: bin/ysc -t yscj -C -
  stdi: |
    foo:
      .size: 10-20
      .like: a.*b
      .list: true
      .base: +Str
  want: |
    {"foo":{".base":"+Str",".list":true,".like":"a.*b",".size":[10,20]}}

- name: json-schema-to-yscj
  cmnd: bin/ysc -t yscj -f jsc -
  stdi: |
    {
      "properties": {
        "enabled": {"type": "boolean", "default": false},
        "flag": {"type": ["boolean", "null"]}
      }
    }
  want: |
    {
      "enabled?": {
        ".base": "+Bool",
        ".init": false
      },
      "flag?": {
        ".base": "+Bool",
        ".null": true
      }
    }

- name: only-null-and-solo-to-json-schema
  cmnd: bin/ysc -t schema.json -
  stdi: |
    version: User
    flag?: +Bool~
    tags?: +Str[$|1+]
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "flag": {
          "type": [
            "boolean",
            "null"
          ]
        },
        "tags": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "array",
              "items": {
                "type": "string"
              },
              "minItems": 1
            }
          ]
        },
        "version": {
          "const": "User"
        }
      },
      "required": [
        "version"
      ],
      "additionalProperties": false
    }

- name: reject-duplicate-hybrid-directive
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    foo:
      .base: +Str /a/
      .like: a
  want: |
    ysc: duplicate yamlschema directive: .like in directive .like

- name: reject-need
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    foo:
      .need: true
      .base: +Str
  want: |
    ysc: unsupported yamlschema directive: .need; use ? on optional keys

- name: reject-old-description
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: +Str 'Old description'
  want: |
    ysc: single-quoted descriptions are unsupported; use "description"

- name: reject-old-size-sentinel
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    foo:
      .base: +Str
      .size: [1, '*']
  want: |
    ysc: unsupported .size "*" bound; use 1+ or [1]

done:
