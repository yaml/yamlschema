#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: ysdc-output-serializations
  cmnd: |
    sh -c '
      input="foo: +Str"
      printf "%s\n" "$input" | bin/ysd -t ysdc -J -C -
      printf "%s\n" "$input" | bin/ysd -t ysdc -
    '
  want: |
    {"foo":"+Str"}
    foo: +Str

- name: collapse-sole-type-pairs
  cmnd: bin/ysd -f ysdc -t ysdc -
  stdi: |
    namespace?:
      .type: +Str
    topologySpreadConstraints?:
      .type: +Any[]
    labels?:
      +Str:
        .type: +Str
    annotated?:
      .type: +Str
      .desc: Kept explicit
  want: |
    namespace?: +Str
    topologySpreadConstraints?: +Any[]
    labels?:
      +Str: +Str
    annotated?:
      .type: +Str
      .desc: Kept explicit

- name: ysd-output-serializations
  cmnd: |
    sh -c '
      input="{\"properties\":{\"foo\":{\"type\":\"string\"}}}"
      printf "%s\n" "$input" | bin/ysd -t ysd -
      printf "%s\n" "$input" | bin/ysd -t ysd -J -C -
    '
  want: |
    # Converted from JSON Schema
    .open: true
    foo?: +Str
    {".open":true,"foo?":"+Str"}

- name: jsc-output-serializations
  cmnd: |
    sh -c '
      input="foo: +Str"
      printf "%s\n" "$input" | bin/ysd -t jsc -C - |
        ys -e "say: IN:read:json/load.type"
      printf "%s\n" "$input" | bin/ysd -t jsc -Y - |
        ys -e "say: IN:read:yaml/load.type"
    '
  want: |
    object
    object

- name: all-input-formats-and-serializations
  cmnd: |
    sh -c '
      dsl="foo: +Str"
      canonical_yaml="foo:\n  .type: +Str"
      canonical_json="{\"foo\":{\".type\":\"+Str\"}}"
      json_schema="{\"properties\":{\"foo\":{\"type\":\"string\"}}}"
      for input in "$dsl" "{\"foo\":\"+Str\"}"; do
        printf "%s\n" "$input" | bin/ysd -f ysd -t jsc -C - |
          ys -e "say: IN:read:json/load.type"
      done
      printf "%b\n" "$canonical_yaml" |
        bin/ysd -f ysdc -t jsc -C - |
          ys -e "say: IN:read:json/load.type"
      printf "%s\n" "$canonical_json" |
        bin/ysd -f ysdc -t jsc -C - |
          ys -e "say: IN:read:json/load.type"
      for input in "$json_schema" "properties: {foo: {type: string}}"; do
        printf "%s\n" "$input" |
          bin/ysd -f jsc -t ysdc -J -C - |
          jq -r ".\"foo?\""
      done
    '
  want: |
    object
    object
    object
    object
    +Str
    +Str

- name: json-schema-to-expanded-yaml
  cmnd: bin/ysd -f jsc -t ysdc -
  stdi: |
    {
      "properties": {"foo": {"type": "string"}},
      "required": ["foo"]
    }
  want: |
    .open: true
    foo: +Str

- name: json-schema-to-json-schema
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "%s\n" \
        "{\"title\":\"Harbor Next Helm Chart Values\",\"type\":\"object\"}" \
        > "$dir/values.schema.json"
      bin/ysd "$dir/values.schema.json" -t jsc -C
      rm -r "$dir"
    '
  want: |
    {"title":"Harbor Next Helm Chart Values","type":"object"}

- name: normalize-all-input-formats-to-json-schema
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "foo: +Str\n" > "$dir/in.ysd.yaml"
      printf "foo:\n  .type: +Str\n" > "$dir/in.ysdc.yaml"
      printf "%s\n" "{\"foo\":{\".type\":\"+Str\"}}" \
        > "$dir/in.ysdc.json"
      printf "%s\n" \
        "{\"type\":\"object\",\"properties\":{\"foo\":{\"type\":\"string\"}},\
    \"required\":[\"foo\"],\"additionalProperties\":false}" \
        > "$dir/in.schema.json"
      for file in \
        "$dir/in.ysd.yaml" \
        "$dir/in.ysdc.yaml" \
        "$dir/in.ysdc.json" \
        "$dir/in.schema.json"
      do
        bin/ysd -NC "$file"
      done
      rm -r "$dir"
    '
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":false,"required":["foo"],"properties":{"foo":{"type":"string"}}}
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":false,"required":["foo"],"properties":{"foo":{"type":"string"}}}
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":false,"required":["foo"],"properties":{"foo":{"type":"string"}}}
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"object","additionalProperties":false,"required":["foo"],"properties":{"foo":{"type":"string"}}}

- name: all-input-file-extensions
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      trap "rm -r \"$dir\"" EXIT
      printf "foo: +Str\n" > "$dir/in.ysd.yaml"
      printf "%s\n" "{\"foo\":\"+Str\"}" > "$dir/in.ysd.json"
      printf "foo: +Str\n" > "$dir/in.ysdc.yaml"
      printf "%s\n" "{\"foo\":\"+Str\"}" > "$dir/in.ysdc.json"
      printf "%s\n" \
        "{\"properties\":{\"foo\":{\"type\":\"string\"}}}" \
        > "$dir/in.schema.json"
      for file in \
        in.schema.json.yaml in.schema.yaml in.schema.yml
      do
        printf "properties: {foo: {type: string}}\n" > "$dir/$file"
      done
      for file in in.ysd.yaml in.ysd.json \
        in.ysdc.yaml in.ysdc.json
      do
        bin/ysd -C "$dir/$file" |
          ys -e "say: IN:read:json/load.properties.foo.type"
      done
      for file in in.schema.json in.schema.json.yaml \
        in.schema.yaml in.schema.yml
      do
        bin/ysd "$dir/$file" | perl -ne "print if /^foo[?]:/"
      done
    '
  want: |
    string
    string
    string
    string
    foo?: +Str
    foo?: +Str
    foo?: +Str
    foo?: +Str

- name: yaml-json-schema-input
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      trap "rm -r \"$dir\"" EXIT
      for file in in.schema.json in.schema.yaml
      do
        printf "%s\n" \
          "type: object" \
          "properties:" \
          "  name:" \
          "    type: string" \
          "required: [name]" \
          "additionalProperties: false" > "$dir/$file"
        bin/ysd "$dir/$file" | perl -ne "print if /^name:/"
        bin/ysd -NC "$dir/$file" | jq -r .properties.name.type
        bin/ysd -Rq "$dir/$file" && echo roundtrip
      done
    '
  want: |
    name: +Str
    string
    roundtrip
    name: +Str
    string
    roundtrip

- name: all-output-file-extensions
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      trap "rm -r \"$dir\"" EXIT
      json="{\"properties\":{\"foo\":{\"type\":\"string\"}}}"
      dsl="foo: +Str"
      printf "%s\n" "$json" | bin/ysd -o "$dir/out.ysd.yaml"
      printf "%s\n" "$json" | bin/ysd -C -o "$dir/out.ysd.json"
      printf "%s\n" "$dsl" | bin/ysd -o "$dir/out.ysdc.yaml"
      printf "%s\n" "$dsl" | bin/ysd -C -o "$dir/out.ysdc.json"
      printf "%s\n" "$dsl" | bin/ysd -C -o "$dir/out.schema.json"
      for file in \
        out.schema.json.yaml out.schema.yaml out.schema.yml
      do
        printf "%s\n" "$dsl" | bin/ysd -o "$dir/$file"
      done
      grep -Fqx "foo?: +Str" "$dir/out.ysd.yaml"
      test "$(jq -r ".\"foo?\"" "$dir/out.ysd.json")" = +Str
      grep -Fqx "foo: +Str" "$dir/out.ysdc.yaml"
      test "$(jq -r .foo "$dir/out.ysdc.json")" = +Str
      test "$(jq -r .properties.foo.type "$dir/out.schema.json")" = string
      for file in \
        out.schema.json.yaml out.schema.yaml out.schema.yml
      do
        grep -Fqx "    type: string" "$dir/$file"
      done
      echo ok
    '
  want: |
    ok

- name: expanded-output-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "foo: +Str\n" | bin/ysd -C -o "$dir/out.ysdc.json"
      cat "$dir/out.ysdc.json"
      printf "foo: +Str\n" | bin/ysd -o "$dir/out.ysdc.yaml"
      cat "$dir/out.ysdc.yaml"
      rm -r "$dir"
    '
  want: |
    {"foo":"+Str"}
    foo: +Str

- name: succinct-output-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "%s\n" \
        "{\"properties\":{\"foo\":{\"type\":\"string\"}}}" |
        bin/ysd -o "$dir/out.ysd.yaml"
      cat "$dir/out.ysd.yaml"
      rm -r "$dir"
    '
  want: |
    # Converted from JSON Schema
    .open: true
    foo?: +Str

- name: json-schema-input-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "%s\n" \
        "{\"properties\":{\"foo\":{\"type\":\"string\"}}}" \
        > "$dir/in.schema.json"
      bin/ysd -t ysdc "$dir/in.schema.json"
      rm -r "$dir"
    '
  want: |
    .open: true
    foo?: +Str

- name: expanded-from-values
  cmnd: |
    sh -c '
      printf "%s\n" "{\"foo\":{\".type\":\"+Str\"}}" |
        bin/ysd -f ysdc -t jsc -C - | fold -w 72
      printf "foo:\n  .type: +Str\n" |
        bin/ysd -f ysdc -t jsc -C - | fold -w 72
    '
  want: |
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"o
    bject","additionalProperties":false,"required":["foo"],"properties":{"fo
    o":{"type":"string"}}}
    {"$schema":"https:\/\/json-schema.org\/draft\/2020-12\/schema","type":"o
    bject","additionalProperties":false,"required":["foo"],"properties":{"fo
    o":{"type":"string"}}}

- name: canonical-like-input
  cmnd: |
    sh -c '
      input="foo:\n  .like: /a.*b/"
      printf "%b\n" "$input" | bin/ysd -f ysdc -t ysdc -J -C -
      printf "%b\n" "$input" | bin/ysd -f ysdc -t jsc -C - |
        ys -e "say: IN:read:json/load.properties.foo.pattern"
      printf "%s\n" "{\"foo\":{\".like\":\"^x$\"}}" |
        bin/ysd -f ysdc -t jsc -C - |
        ys -e "say: IN:read:json/load.properties.foo.pattern"
    '
  want: |
    {"foo":{".type":"+Str",".like":"\/a.*b\/"}}
    /a.*b/
    ^x$

- name: reject-regex-directives-in-wrong-source-form
  cmnd: |
    sh -c '
      printf "foo:\n  .like: a\n" |
        bin/ysd -f ysd -t ysdc -J -C - 2>&1 | sed -n 1p
      for key in .match .find; do
        printf "foo:\n  %s: a\n" "$key" |
          bin/ysd -f ysdc -t jsc -C - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysd: unsupported .ysd directive: .like; use .match or .find
    ysd: unsupported .ysdc directive: .match; use .like
    ysd: unsupported .ysdc directive: .find; use .like

- name: expanded-input-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "foo:\n  .type: +Str\n" > "$dir/in.ysdc.yaml"
      printf "%s\n" "{\"foo\":{\".type\":\"+Str\"}}" \
        > "$dir/in.ysdc.json"
      bin/ysd -t ysdc -J -C "$dir/in.ysdc.yaml"
      bin/ysd -t ysdc "$dir/in.ysdc.json"
      rm -r "$dir"
    '
  want: |
    {"foo":"+Str"}
    foo: +Str

- name: succinct-input-extension-inference
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      printf "foo?: +Str\n" > "$dir/in.ysd.yaml"
      bin/ysd -t jsc -C "$dir/in.ysd.yaml" |
        ys -e "say: IN:read:json/load.properties.foo.type"
      rm -r "$dir"
    '
  want: |
    string

- name: reject-old-format-slugs
  cmnd: |
    sh -c '
      for format in ysc yscy yscj ysc.yaml ysc.json ysxy ysxj; do
        printf "foo: +Str\n" |
          bin/ysd -t "$format" - 2>&1 | sed -n 1p
      done
      for format in ysc yscy yscj ysc.yaml ysc.json ysxy ysxj; do
        printf "foo: +Str\n" |
          bin/ysd -f "$format" -t jsc - 2>&1 | sed -n 1p
      done
    '
  want: |
    ysd: unsupported format: ysc
    ysd: unsupported format: yscy
    ysd: unsupported format: yscj
    ysd: unsupported format: ysc.yaml
    ysd: unsupported format: ysc.json
    ysd: unsupported format: ysxy
    ysd: unsupported format: ysxj
    ysd: unsupported format: ysc
    ysd: unsupported format: yscy
    ysd: unsupported format: yscj
    ysd: unsupported format: ysc.yaml
    ysd: unsupported format: ysc.json
    ysd: unsupported format: ysxy
    ysd: unsupported format: ysxj

- name: reject-old-expanded-extension
  cmnd: |
    sh -c '
      dir=$(mktemp -d)
      for extension in ysc.yaml ysc.json ysx.yaml ysx.json; do
        printf "foo: +Str\n" > "$dir/in.$extension"
        bin/ysd -t jsc "$dir/in.$extension" 2>&1 | sed -n 1p
        printf "foo: +Str\n" |
          bin/ysd -o "$dir/out.$extension" 2>&1 | sed -n 1p
      done
      rm -r "$dir"
    '
  want: |
    ysd: unsupported file extension: .ysc.yaml
    ysd: unsupported file extension: .ysc.yaml
    ysd: unsupported file extension: .ysc.json
    ysd: unsupported file extension: .ysc.json
    ysd: unsupported file extension: .ysx.yaml
    ysd: unsupported file extension: .ysx.yaml
    ysd: unsupported file extension: .ysx.json
    ysd: unsupported file extension: .ysx.json

done:
