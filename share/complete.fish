complete -c ysd -s t -l to -d 'Output format' -x \
  -a 'ysd ysdc jsc'
complete -c ysd -s f -l from -d 'Input format' -x \
  -a 'ysd ysdc jsc'
complete -c ysd -s o -l output -d 'Output file' -r
complete -c ysd -s Y -l yaml -d 'Emit YAML output'
complete -c ysd -s J -l json -d 'Emit JSON output'
complete -c ysd -s N -l norm -d 'Normalize JSON Schema'
complete -c ysd -s R -l roundtrip -d 'Check roundtrip'
complete -c ysd -s q -l quiet -d 'Suppress roundtrip output'
complete -c ysd -s C -l compact -d 'Emit compact JSON'
complete -c ysd -l help -d 'Show help'
complete -c ysd -l version -d 'Show version'

function __fish_complete_ysd_inputs
  __fish_complete_suffix .ysd.yaml
  __fish_complete_suffix .ysd.json
  __fish_complete_suffix .ysdc.yaml
  __fish_complete_suffix .ysdc.json
  __fish_complete_suffix .schema.json
  __fish_complete_suffix .schema.json.yaml
  __fish_complete_suffix .schema.yaml
  __fish_complete_suffix .schema.yml
end

complete -c ysd -a '(__fish_complete_ysd_inputs)' \
  -d 'Input schema'
