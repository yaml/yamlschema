#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: composed-and-hybrid-equivalence
  cmnd: bin/ysc -t yscj -
  stdi: |
    succinct: +Str[] /a.*b/ 10-20
    hybrid:
      .base: +Str[] /a.*b/ 10-20
      .title: The "Good" Parts
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
        ".title": "The \"Good\" Parts"
      }
    }

- name: inferred-types-and-const
  cmnd: bin/ysc -t yscj -
  stdi: |
    pattern: /a.*b/
    numbers: +Int [1,2,3]
    forced: +Str [1,2]
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
        ".range": [
          0.5,
          1
        ]
      },
      "constant": {
        ".base": "+Str",
        ".const": "User"
      },
      "object": {
        "child?": "+Bool"
      }
    }

- name: pattern-forms-and-size
  cmnd: bin/ysc -t yscj -
  stdi: |
    url: =~"https?://.*" 1+
    spaced: =~"a b" 2-4
    alias: match:"still accepted"
    anchored: match:"^already$"
    found: find:"a/b c"
    simple: /a.*b/
    explicit:
      .find: raw value
  want: |
    {
      "url": {
        ".base": "+Str",
        ".like": "^https?://.*$",
        ".size": [
          1
        ]
      },
      "spaced": {
        ".base": "+Str",
        ".like": "^a b$",
        ".size": [
          2,
          4
        ]
      },
      "alias": {
        ".base": "+Str",
        ".like": "^still accepted$"
      },
      "anchored": {
        ".base": "+Str",
        ".like": "^^already$$"
      },
      "found": {
        ".base": "+Str",
        ".like": "a/b c"
      },
      "simple": {
        ".base": "+Str",
        ".like": "a.*b"
      },
      "explicit": {
        ".base": "+Str",
        ".like": "raw value"
      }
    }

- name: list-size-forms
  cmnd: bin/ysc -t yscj -
  stdi: |
    key?[!1+]: +Str
    value?: +Str[$|0-3]
    alias?: +Str[+]
    exact?: +Map[+Any] 10
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
        ".size": [
          10,
          10
        ],
        "+Str": "+Any"
      }
    }

- name: nullable-default-title-description
  cmnd: bin/ysc -t yscj -
  stdi: |
    flag?: +Bool~ =false title:"Flag" "Whether it is enabled"
    label?: +Str ="pretty good"
    level?: base:+Str enum:[debug,info] init:info desc:"Log level"
  want: |
    {
      "flag?": {
        ".base": "+Bool",
        ".null": true,
        ".init": false,
        ".title": "Flag",
        ".desc": "Whether it is enabled"
      },
      "label?": {
        ".type": "+Str",
        ".init": "pretty good"
      },
      "level?": {
        ".base": "+Str",
        ".enum": [
          "debug",
          "info"
        ],
        ".init": "info",
        ".desc": "Log level"
      }
    }

- name: explicit-order-is-declarative
  cmnd: bin/ysc -t yscj -C -
  stdi: |
    foo:
      .size: 10-20
      .match: a.*b
      .list: true
      .base: +Str
  want: |
    {"foo":{".base":"+Str",".list":true,".like":"^a.*b$",".size":[10,20]}}

- name: direct-and-refined-type-directives
  cmnd: bin/ysc -t yscj -
  stdi: |
    +named: +Str
    plain: +Str
    named: +named
    annotated: +Float =1.5 title:"Number" "A number"
    refined:
      .type: +Str
      .enum: [foo, bar]
  want: |
    {
      "+named": "+Str",
      "plain": "+Str",
      "named": "+named",
      "annotated": {
        ".type": "+Float",
        ".init": 1.5,
        ".title": "Number",
        ".desc": "A number"
      },
      "refined": {
        ".base": "+Str",
        ".enum": ["foo","bar"]
      }
    }

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
        ".type": "+Bool",
        ".init": false
      },
      "flag?": {
        ".base": "+Bool",
        ".null": true
      }
    }

- name: const-null-and-solo-to-json-schema
  cmnd: bin/ysc -t schema.json -
  stdi: |
    version: +Str ==User
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
      .find: a
  want: |
    ysc: duplicate yamlschema directive: .like in directive .find

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

- name: reject-whitespace-in-regex-literal
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: /a b/
  want: |
    ysc: regex literals cannot contain whitespace; use find:"..."

- name: reject-slash-in-regex-literal
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: /a/b/
  want: |
    ysc: regex literals cannot contain /; use find:"..."

- name: reject-pipe-enum
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: debug|info
  want: |
    ysc: pipe enums are unsupported; use +Base [a,b]

- name: reject-compact-enum-without-base
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: enum:[debug,info]
  want: |
    ysc: compact enum requires a preceding base reference

- name: reject-compact-enum-punctuation
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: +Str [good,bad/value]
  want: |
    ysc: compact enum values allow alphanumerics, whitespace, .-_+; use .enum

- name: reject-quote-in-labeled-pattern
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: match:"a"b"
  want: |
    ysc: tight quoted values cannot contain a double quote

- name: reject-quote-in-operator-match
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: =~"a"b"
  want: |
    ysc: tight quoted values cannot contain a double quote

- name: reject-old-size-sentinel
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    foo:
      .base: +Str
      .size: [1, '*']
  want: |
    ysc: unsupported .size "*" bound; use 1+ or [1]

- name: compact-enum-whitespace-members
  cmnd: bin/ysc -t yscj -C -
  stdi: |
    tight: +Str [foo,bar,foo bar,bar foo]
    padded: +Str [ foo, bar, foo bar, bar foo ]
  want: |
    {"tight":{".base":"+Str",".enum":["foo","bar","foo bar","bar foo"]},"padded":{".base":"+Str",".enum":["foo","bar","foo bar","bar foo"]}}

- name: reject-quoted-compact-enum-value
  cmnd: |
    sh -c 'bin/ysc -t yscj -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: +Str [foo,"bar foo"]
  want: |
    ysc: quoted values are not allowed in compact enum; use .enum

- name: const-and-default-forms
  cmnd: bin/ysc -t yscj -C -
  stdi: |
    short: +Str ==User
    quoted: +Str =="foo bar"
    labeled: const:"foo bar" base:+Str
    default: +Str =User
    enum-marked: +Str [=User]
    enum-default: +Str [User] =User
  want: |
    {"short":{".base":"+Str",".const":"User"},"quoted":{".base":"+Str",".const":"foo bar"},"labeled":{".base":"+Str",".const":"foo bar"},"default":{".type":"+Str",".init":"User"},"enum-marked":{".base":"+Str",".enum":["User"],".init":"User"},"enum-default":{".base":"+Str",".enum":["User"],".init":"User"}}

- name: labeled-clauses-in-arbitrary-order
  cmnd: bin/ysc -t yscj -C -
  stdi: |
    string: desc:"Words" size:1-3 =~"a b" title:"Title" init:x base:+Str
    search: find:"a/b c" base:+Str
    number: range:1..10 base:+Int
    sequence: null:true uniq:true solo:true size:1+ item:+Str
      list:true base:+Any
    alternate: also:former base:+Str
    choice: enum:[a,b c] base:+Str
  want: |
    {"string":{".base":"+Str",".like":"^a b$",".size":[1,3],".init":"x",".title":"Title",".desc":"Words"},"search":{".base":"+Str",".like":"a\/b c"},"number":{".base":"+Int",".range":[1,10]},"sequence":{".base":"+Any",".list":true,".item":"+Str",".size":[1],".solo":true,".uniq":true,".null":true},"alternate":{".base":"+Str",".also":"former"},"choice":{".base":"+Str",".enum":["a","b c"]}}

- name: reject-renamed-tight-keywords
  cmnd: |
    sh -c '
      for value in titl:Old just:Old only:Old like:Old mini:1 maxi:10; do
        printf "foo: +Str %s\n" "$value" |
          bin/ysc -t yscj -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysc: unsupported yamlschema keyword: titl; use title
    ysc: unsupported yamlschema keyword: just; use const
    ysc: unsupported yamlschema keyword: only; use const
    ysc: unsupported yamlschema keyword: like; use match
    ysc: unsupported yamlschema keyword: mini; use range
    ysc: unsupported yamlschema keyword: maxi; use range

- name: reject-renamed-explicit-directives
  cmnd: |
    sh -c '
      for key in .titl .just .only .mini .maxi; do
        printf "foo:\n  %s: Old\n" "$key" |
          bin/ysc -t yscj -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysc: unsupported yamlschema directive: .titl; use .title
    ysc: unsupported yamlschema directive: .just; use .const
    ysc: unsupported yamlschema directive: .only; use .const
    ysc: unsupported yamlschema directive: .mini; use .range
    ysc: unsupported yamlschema directive: .maxi; use .range

- name: reject-invalid-type-directives
  cmnd: |
    sh -c '
      printf "foo:\n  .type: +Str\n  .base: +Str\n" |
        bin/ysc -t yscj -C - 2>&1 | sed -n 1p
      printf "foo:\n  .type: +Str[]\n" |
        bin/ysc -t yscj -C - 2>&1 | sed -n 1p
    '
  want: |
    ysc: yamlschema type cannot contain both .type and .base
    ysc: yamlschema .type requires a bare type reference

done:
