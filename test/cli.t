#!/usr/bin/env ys-0

use ys::taptest: :all

test::

- name: no-args
  cmnd: bin/ysc
  want: |
    Usage: ysc (-t FORMAT | -o FILE) INPUT

    Convert between JSON Schema and yamlschema formats.

    Arguments:
      INPUT                 Input schema path. Use "-" for stdin.

    Options:
      -t, --to FORMAT       Output format. Currently supports "ysc.yaml".
      -o, --output FILE     Write output to FILE. Use "-" for stdout.
          --help            Show this help text.
          --version         Show version.

- name: help
  cmnd: bin/ysc --help
  want: |
    Usage: ysc (-t FORMAT | -o FILE) INPUT

    Convert between JSON Schema and yamlschema formats.

    Arguments:
      INPUT                 Input schema path. Use "-" for stdin.

    Options:
      -t, --to FORMAT       Output format. Currently supports "ysc.yaml".
      -o, --output FILE     Write output to FILE. Use "-" for stdout.
          --help            Show this help text.
          --version         Show version.

- name: version
  cmnd: bin/ysc --version
  want: |
    ysc 0.0.0

done:
