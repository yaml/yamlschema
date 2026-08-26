# shellcheck shell=bash disable=SC2207

_ysd() {
  local cur prev opts formats
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}
  opts='-t --to -f --from -o --output -Y --yaml -J --json
    -N --norm -R --roundtrip -q --quiet -C --compact
    --help --version'
  formats='ysd ysdc jsc'

  case $prev in
    -t|--to|-f|--from)
      COMPREPLY=( $(compgen -W "$formats" -- "$cur") )
      return 0
      ;;
    -o|--output)
      COMPREPLY=( $(compgen -f -- "$cur") )
      return 0
      ;;
  esac

  case $cur in
    -*)
      COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
      return 0
      ;;
  esac

  COMPREPLY=(
    $(compgen -f -X '!*.ysd.yaml' -- "$cur")
    $(compgen -f -X '!*.ysd.json' -- "$cur")
    $(compgen -f -X '!*.ysdc.yaml' -- "$cur")
    $(compgen -f -X '!*.ysdc.json' -- "$cur")
    $(compgen -f -X '!*.schema.json' -- "$cur")
    $(compgen -f -X '!*.schema.json.yaml' -- "$cur")
    $(compgen -f -X '!*.schema.yaml' -- "$cur")
    $(compgen -f -X '!*.schema.yml' -- "$cur")
    $(compgen -d -- "$cur")
  )
}

complete -o filenames -F _ysd ysd
