#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: composed-and-hybrid-equivalence
  cmnd: bin/ysd -t ysdc -J -
  stdi: |
    succinct: +Str[] ~~"a.*b" 10-20
    hybrid:
      .type: +Str[] ~~"a.*b" 10-20
      .title: The "Good" Parts
  want: |
    {
      "succinct": {
        ".list": {
          ".type": "+Str",
          ".like": "a.*b"
        },
        ".size": [
          10,
          20
        ]
      },
      "hybrid": {
        ".title": "The \"Good\" Parts",
        ".list": {
          ".type": "+Str",
          ".like": "a.*b"
        },
        ".size": [
          10,
          20
        ]
      }
    }

- name: inferred-types-and-const
  cmnd: bin/ysd -t ysdc -J -
  stdi: |
    pattern: ~~"a.*b"
    numbers: +Int [1,2,3]
    forced: +Str [1,2]
    ratio: 0.5..1
    constant: User
    object:
      child?: +Bool
  want: |
    {
      "pattern": {
        ".type": "+Str",
        ".like": "a.*b"
      },
      "numbers": {
        ".type": "+Int",
        ".enum": [
          1,
          2,
          3
        ]
      },
      "forced": {
        ".type": "+Str",
        ".enum": [
          "1",
          "2"
        ]
      },
      "ratio": {
        ".type": "+Num",
        ".range": [
          0.5,
          1
        ]
      },
      "constant": {
        ".type": "+Str",
        ".const": "User"
      },
      "object": {
        "child?": "+Bool"
      }
    }

- name: pattern-forms-and-size
  cmnd: bin/ysd -t ysdc -J -
  stdi: |
    url: ~"https?://.*" 1+
    spaced: ~"a b" 2-4
    alias: match:"still accepted"
    anchored: match:"^already$"
    found: find:"a/b c"
    simple: ~~"a.*b"
    explicit:
      .find: raw value
  want: |
    {
      "url": {
        ".type": "+Str",
        ".like": "^https?://.*$",
        ".size": [
          1
        ]
      },
      "spaced": {
        ".type": "+Str",
        ".like": "^a b$",
        ".size": [
          2,
          4
        ]
      },
      "alias": {
        ".type": "+Str",
        ".like": "^still accepted$"
      },
      "anchored": {
        ".type": "+Str",
        ".like": "^^already$$"
      },
      "found": {
        ".type": "+Str",
        ".like": "a/b c"
      },
      "simple": {
        ".type": "+Str",
        ".like": "a.*b"
      },
      "explicit": {
        ".type": "+Str",
        ".like": "raw value"
      }
    }

- name: list-size-forms
  cmnd: bin/ysd -t ysdc -J -
  stdi: |
    key?: +Str[1+,!]
    value?: +Str[0-3,$]
    alias?: +Str[+]
    exact?: +Map{+Any} 10
  want: |
    {
      "key?": {
        ".list": "+Str",
        ".size": [
          1
        ],
        ".uniq": true
      },
      "value?": {
        ".list": "+Str",
        ".size": [
          0,
          3
        ],
        ".solo": true
      },
      "alias?": {
        ".list": "+Str",
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

- name: explicit-any-canonicalizes-to-solo-list
  cmnd: bin/ysd -f ysd -t ysdc -J -
  stdi: |
    value:
      .any:
      - .type: +Str
        .match: x
      - .type: +Str[]
        .match: x
        .size: [1]
    mismatch:
      .any:
      - +Str
      - +Int[]
    annotated:
      .any:
      - +Int
      - +Int[]
      .title: Number or numbers
      .desc: Accept one integer or a list
  want: |
    {
      "value": {
        ".list": {
          ".type": "+Str",
          ".like": "^x$"
        },
        ".size": [
          1
        ],
        ".solo": true
      },
      "mismatch": {
        ".any": [
          "+Str",
          {
            ".list": "+Int"
          }
        ]
      },
      "annotated": {
        ".title": "Number or numbers",
        ".desc": "Accept one integer or a list",
        ".list": "+Int",
        ".solo": true
      }
    }

- name: composable-list-property-spellings
  cmnd: sh -c 'bin/ysd -t ysdc -J -C - | fold -w 72'
  stdi: |
    canonical: +Str[1-10,$!]
    split: +Str[1-10,$,!]
    spaced: +Str[1-10 $ !]
    compact: +Str[1-10$!]
  want: |
    {"canonical":{".list":"+Str",".size":[1,10],".solo":true,".uniq":true},"
    split":{".list":"+Str",".size":[1,10],".solo":true,".uniq":true},"spaced
    ":{".list":"+Str",".size":[1,10],".solo":true,".uniq":true},"compact":{"
    .list":"+Str",".size":[1,10],".solo":true,".uniq":true}}

- name: explicit-list-full-form
  cmnd: bin/ysd -t ysdc -Y -
  stdi: |
    simple:
      .list: +Str
    constrained:
      .list:
        .type: +Str
        .match: word
      .size: 1
    enumerated: +Str[] [a, b]
  want: |
    simple:
      .list: +Str
    constrained:
      .list:
        .type: +Str
        .like: ^word$
      .size: [1, 1]
    enumerated:
      .list:
        .type: +Str
        .enum: [a, b]

- name: reject-invalid-list-properties
  cmnd: |
    sh -c '
      for value in "+Str[1-10,3]" "+Str[$,$]" "+Str[!,!]" \
                   "+Str[1-10|$!]"; do
        printf "x: %s\n" "$value" |
          bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysd: list suffix contains multiple size constraints
    ysd: list suffix contains duplicate $ flag
    ysd: list suffix contains duplicate ! flag
    ysd: unsupported | in list suffix; use comma

- name: nullable-default-title-description
  cmnd: bin/ysd -t ysdc -J -
  stdi: |
    flag?: -"Whether it is enabled" +Bool~ =false title:"Flag"
    label?: +Str ="pretty good"
    level?: type:+Str enum:[debug,info] init:info desc:"Log level"
  want: |
    {
      "flag?": {
        ".title": "Flag",
        ".desc": "Whether it is enabled",
        ".type": "+Bool",
        ".null": true,
        ".init": false
      },
      "label?": {
        ".type": "+Str",
        ".init": "pretty good"
      },
      "level?": {
        ".desc": "Log level",
        ".type": "+Str",
        ".enum": [
          "debug",
          "info"
        ],
        ".init": "info"
      }
    }

- name: explicit-order-is-declarative
  cmnd: bin/ysd -t ysdc -J -C -
  stdi: |
    foo:
      .size: 10-20
      .match: a.*b
      .type: +Str[]
  want: |
    {"foo":{".list":{".type":"+Str",".like":"^a.*b$"},".size":[10,20]}}

- name: direct-and-refined-type-directives
  cmnd: bin/ysd -t ysdc -J -
  stdi: |
    +named: +Str
    plain: +Str
    named: +named
    annotated: +Float -"A number" =1.5 title:"Number"
    refined:
      .type: +Str
      .enum: [foo, bar]
  want: |
    {
      "+named": "+Str",
      "plain": "+Str",
      "named": "+named",
      "annotated": {
        ".title": "Number",
        ".desc": "A number",
        ".type": "+Float",
        ".init": 1.5
      },
      "refined": {
        ".type": "+Str",
        ".enum": [
          "foo",
          "bar"
        ]
      }
    }

- name: json-schema-to-ysdc-json
  cmnd: bin/ysd -t ysdc -J -f jsc -
  stdi: |
    {
      "properties": {
        "enabled": {"type": "boolean", "default": false},
        "flag": {"type": ["boolean", "null"]}
      }
    }
  want: |
    {
      ".open": true,
      "enabled?": {
        ".type": "+Bool",
        ".init": false
      },
      "flag?": {
        ".type": "+Bool",
        ".null": true
      }
    }

- name: const-null-and-solo-to-json-schema
  cmnd: bin/ysd -t jsc -
  stdi: |
    version: +Str ==User
    flag?: +Bool~
    tags?: +Str[1+,$]
  want: |
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "version"
      ],
      "properties": {
        "version": {
          "const": "User"
        },
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
              "minItems": 1,
              "items": {
                "type": "string"
              }
            }
          ]
        }
      }
    }

- name: reject-duplicate-hybrid-directive
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    foo:
      .type: +Str ~~"a"
      .find: a
  want: |
    ysd: duplicate yamlschema directive: .like in directive .find

- name: explicit-need
  cmnd: bin/ysd -t jsc -C -
  stdi: |
    foo:
      .type: +Str
      .need: [bar]
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":false,"required":["foo"],"dependentRequired":{"foo":["bar"]},"properties":{"foo":{"type":"string"}}}

- name: reject-list-directive
  cmnd: |
    sh -c '
      printf "foo:\n  .type: +Any\n  .list: true\n" |
        bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p
      printf "foo: +Any list:true\n" |
        bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p
    '
  want: |
    ysd: yamlschema .list requires an item schema
    ysd: unsupported yamlschema keyword: list; use [] on the type

- name: reject-retired-item-and-canonical-list-forms
  cmnd: |
    sh -c '
      printf "foo:\n  .item: +Str\n" |
        bin/ysd -t ysdc -C - 2>&1 | sed -n 1p
      printf "foo: +Any item:+Str\n" |
        bin/ysd -t ysdc -C - 2>&1 | sed -n 1p
      printf "foo:\n  .type: +Str[]\n" |
        bin/ysd -f ysdc -t jsc -C - 2>&1 | sed -n 1p
      printf "foo:\n  .any[]: [+Str, +Int]\n" |
        bin/ysd -f ysdc -t jsc -C - 2>&1 | sed -n 1p
    '
  want: |
    ysd: unsupported yamlschema directive: .item; use .list
    ysd: unsupported yamlschema keyword: item; use .list
    ysd: unsupported .ysdc list type; use .list
    ysd: unsupported .ysdc directive: .any[]; use .list

- name: reject-key-side-list-syntax
  cmnd: |
    sh -c '
      for key in "foo[]" "foo?[]" "foo[1-3]" "foo[]?"; do
        printf "%s: +Str\n" "$key" |
          bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysd: unsupported list syntax on key foo[]; put it on the value type
    ysd: unsupported list syntax on key foo?[]; put it on the value type
    ysd: unsupported list syntax on key foo[1-3]; put it on the value type
    ysd: unsupported list syntax on key foo[]?; put it on the value type

- name: reject-old-description
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: +Str 'Old description'
  want: |
    ysd: single-quoted descriptions are unsupported; use "description"

- name: reject-slash-regex-syntax
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: /a/
  want: |
    ysd: slash regex syntax is unsupported; use ~~"pattern"

- name: reject-slash-in-regex-literal
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: /a/b/
  want: |
    ysd: slash regex syntax is unsupported; use ~~"pattern"

- name: reject-pipe-enum
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: debug|info
  want: |
    ysd: pipe enums are unsupported; use +Base [a,b]

- name: reject-compact-enum-without-base
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: enum:[debug,info]
  want: |
    ysd: compact enum requires a preceding type reference

- name: reject-compact-enum-punctuation
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: +Str [good,bad/value]
  want: |
    ysd: compact enum values allow alphanumerics, whitespace, .-_+; use .enum

- name: reject-quote-in-labeled-pattern
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: match:"a"b"
  want: |
    ysd: YSD scalar DSL quoted values cannot contain a double quote

- name: reject-quote-in-compact-match
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: ~"a"b"
  want: |
    ysd: YSD scalar DSL quoted values cannot contain a double quote

- name: reject-old-match-syntax
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: +Str =~"abc"
  want: |
    ysd: unsupported whole-string match syntax; use ~"pattern"

- name: reject-old-size-sentinel
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    foo:
      .type: +Str
      .size: [1, '*']
  want: |
    ysd: unsupported .size "*" bound; use 1+ or [1]

- name: compact-enum-whitespace-members
  cmnd: bin/ysd -t ysdc -J -C -
  stdi: |
    tight: +Str [foo,bar,foo bar,bar foo]
    padded: +Str [ foo, bar, foo bar, bar foo ]
  want: |
    {"tight":{".type":"+Str",".enum":["foo","bar","foo bar","bar foo"]},"padded":{".type":"+Str",".enum":["foo","bar","foo bar","bar foo"]}}

- name: reject-quoted-compact-enum-value
  cmnd: |
    sh -c 'bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p'
  stdi: |
    foo: +Str [foo,"bar foo"]
  want: |
    ysd: quoted values are not allowed in compact enum; use .enum

- name: const-and-default-forms
  cmnd: bin/ysd -t ysdc -J -C -
  stdi: |
    short: +Str ==User
    quoted: +Str =="foo bar"
    plus: +Str =="+Map("
    labeled: const:"foo bar" type:+Str
    default: +Str =User
    enum-marked: +Str [=User]
    enum-default: +Str [User] =User
  want: |
    {"short":{".type":"+Str",".const":"User"},"quoted":{".type":"+Str",".const":"foo bar"},"plus":{".type":"+Str",".const":"+Map("},"labeled":{".type":"+Str",".const":"foo bar"},"default":{".type":"+Str",".init":"User"},"enum-marked":{".type":"+Str",".enum":["User"],".init":"User"},"enum-default":{".type":"+Str",".enum":["User"],".init":"User"}}

- name: labeled-clauses-in-arbitrary-order
  cmnd: bin/ysd -t ysdc -J -C -
  stdi: |
    string: desc:"Words" size:1-3 ~"a b" title:"Title" init:x type:+Str
    search: ~~"a/b c" type:+Str
    number: range:1..10 type:+Int
    sequence: null:true uniq:true solo:true size:1+ type:+Str[]
    alternate: also:former type:+Str
    choice: enum:[a,b c] type:+Str
  want: |
    {"string":{".title":"Title",".desc":"Words",".type":"+Str",".like":"^a b$",".size":[1,3],".init":"x"},"search":{".type":"+Str",".like":"a\/b c"},"number":{".type":"+Int",".range":[1,10]},"sequence":{".list":"+Str",".size":[1],".solo":true,".uniq":true,".null":true},"alternate":{".type":"+Str",".also":"former"},"choice":{".type":"+Str",".enum":["a","b c"]}}

- name: reject-renamed-dsl-keywords
  cmnd: |
    sh -c '
      for value in base:+Str titl:Old just:Old only:Old like:Old mini:1 maxi:10; do
        printf "foo: +Str %s\n" "$value" |
          bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysd: unsupported yamlschema keyword: base; use type
    ysd: unsupported yamlschema keyword: titl; use title
    ysd: unsupported yamlschema keyword: just; use const
    ysd: unsupported yamlschema keyword: only; use const
    ysd: unsupported yamlschema keyword: like; use match
    ysd: unsupported yamlschema keyword: mini; use range
    ysd: unsupported yamlschema keyword: maxi; use range

- name: reject-renamed-explicit-directives
  cmnd: |
    sh -c '
      for key in .titl .just .only .mini .maxi; do
        printf "foo:\n  %s: Old\n" "$key" |
          bin/ysd -t ysdc -J -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysd: unsupported yamlschema directive: .titl; use .title
    ysd: unsupported yamlschema directive: .just; use .const
    ysd: unsupported yamlschema directive: .only; use .const
    ysd: unsupported yamlschema directive: .mini; use .range
    ysd: unsupported yamlschema directive: .maxi; use .range

- name: type-directive-accepts-complete-dsl
  cmnd: |
    sh -c '
      printf "foo:\n  .type: +Str[1+]\n" |
        bin/ysd -t ysdc -J -C -
      for format in ysd ysdc; do
        printf "foo:\n  .base: +Str\n" |
          bin/ysd -f "$format" -t ysdc -J -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    {"foo":{".list":"+Str",".size":[1]}}
    ysd: unsupported yamlschema directive: .base; use .type
    ysd: unsupported yamlschema directive: .base; use .type

done:
