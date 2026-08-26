#compdef ysd

autoload -Uz compinit
if (( ! $+functions[compdef] )); then
  if [[ -n ${YAMLSCHEMA_ROOT:-} ]]; then
    mkdir -p "$YAMLSCHEMA_ROOT/.cache"
    compinit -d "$YAMLSCHEMA_ROOT/.cache/zcompdump"
  else
    compinit
  fi
fi

_ysd() {
  local -a formats
  local file_glob

  formats=(
    'ysd:.ysd format'
    'ysdc:.ysdc format'
    'jsc:JSON Schema'
  )
  file_glob='*.{ysd.yaml,ysd.json,ysdc.yaml,ysdc.json,'
  file_glob+='schema.json,schema.json.yaml,schema.yaml,schema.yml}'

  _arguments -s -S \
    '(-t --to)'{-t,--to}'[Output format]:format:->formats' \
    '(-f --from)'{-f,--from}'[Input format]:format:->formats' \
    '(-o --output)'{-o,--output}'[Output file]:file:_files' \
    '(-Y --yaml -J --json)'{-Y,--yaml}'[Emit YAML output]' \
    '(-Y --yaml -J --json)'{-J,--json}'[Emit JSON output]' \
    '(-N --norm)'{-N,--norm}'[Normalize JSON Schema]' \
    '(-R --roundtrip)'{-R,--roundtrip}'[Check roundtrip]' \
    '(-q --quiet)'{-q,--quiet}'[Suppress roundtrip output]' \
    '(-C --compact)'{-C,--compact}'[Emit compact JSON]' \
    '(- *)--help[Show help]' \
    '(- *)--version[Show version]' \
    "*:input schema:_files -g \"$file_glob\""

  case $state in
    formats)
      _describe 'schema format' formats
      ;;
  esac
}

compdef _ysd ysd
