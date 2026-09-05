$YsdCompletion = {
    param(
        [string]$WordToComplete,
        [System.Management.Automation.Language.CommandAst]$CommandAst
    )

    function Complete-YsdPath {
        param(
            [string]$Word,
            [bool]$InputOnly
        )

        $Suffixes = @(
            '.ysd.yaml'
            '.ysd.json'
            '.ysdc.yaml'
            '.ysdc.json'
            '.schema.json'
            '.schema.json.yaml'
            '.schema.yaml'
            '.schema.yml'
        )
        $Parent = Split-Path -Parent $Word
        $Leaf = Split-Path -Leaf $Word
        $SearchDirectory = if ($Parent) { $Parent } else { '.' }

        Get-ChildItem -LiteralPath $SearchDirectory `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $Item = $_
                $Item.Name -like "$Leaf*" -and
                ($Item.PSIsContainer -or -not $InputOnly -or
                    ($Suffixes | Where-Object {
                        $Item.Name.EndsWith(
                            $_,
                            [StringComparison]::OrdinalIgnoreCase
                        )
                    }))
            } |
            Sort-Object -Property @{ Expression = 'PSIsContainer';
                Descending = $true }, Name |
            ForEach-Object {
                $CompletionText = if ($Parent) {
                    Join-Path $Parent $_.Name
                }
                else {
                    $_.Name
                }
                $ResultType = if ($_.PSIsContainer) {
                    $CompletionText += [IO.Path]::DirectorySeparatorChar
                    'ProviderContainer'
                }
                else {
                    'ProviderItem'
                }
                if ($CompletionText -match '\s' -or
                    $CompletionText.Contains("'")) {
                    $Escaped = $CompletionText.Replace("'", "''")
                    $CompletionText = "'$Escaped'"
                }
                [System.Management.Automation.CompletionResult]::new(
                    $CompletionText,
                    $_.Name,
                    $ResultType,
                    $_.FullName
                )
            }
    }

    $Options = [ordered]@{
        '-t' = 'Output format'
        '--to' = 'Output format'
        '-f' = 'Input format'
        '--from' = 'Input format'
        '-o' = 'Output file'
        '--output' = 'Output file'
        '-Y' = 'Emit YAML output'
        '--yaml' = 'Emit YAML output'
        '-J' = 'Emit JSON output'
        '--json' = 'Emit JSON output'
        '-N' = 'Normalize JSON Schema'
        '--norm' = 'Normalize JSON Schema'
        '-R' = 'Check roundtrip'
        '--roundtrip' = 'Check roundtrip'
        '-q' = 'Suppress roundtrip output'
        '--quiet' = 'Suppress roundtrip output'
        '-C' = 'Emit compact JSON'
        '--compact' = 'Emit compact JSON'
        '--upgrade' = 'Upgrade from repository default branch'
        '--help' = 'Show help'
        '--version' = 'Show version'
    }
    $Formats = [ordered]@{
        ysd = '.ysd format'
        ysdc = '.ysdc format'
        jsc = 'JSON Schema'
    }
    $Elements = @($CommandAst.CommandElements | ForEach-Object {
        $_.Extent.Text
    })
    $Previous = ''

    if ($Elements.Count -gt 1) {
        $Last = $Elements[-1]
        if ($WordToComplete -and $Last -eq $WordToComplete) {
            if ($Elements.Count -gt 2) {
                $Previous = $Elements[-2]
            }
        }
        else {
            $Previous = $Last
        }
    }

    if ($Previous -in @('-t', '--to', '-f', '--from')) {
        foreach ($Format in $Formats.GetEnumerator()) {
            if ($Format.Name -like "$WordToComplete*") {
                [System.Management.Automation.CompletionResult]::new(
                    $Format.Name,
                    $Format.Name,
                    'ParameterValue',
                    $Format.Value
                )
            }
        }
        return
    }

    if ($Previous -in @('-o', '--output')) {
        Complete-YsdPath $WordToComplete $false
        return
    }

    if ($WordToComplete -like '-*') {
        foreach ($Option in $Options.GetEnumerator()) {
            if ($Option.Name -like "$WordToComplete*") {
                [System.Management.Automation.CompletionResult]::new(
                    $Option.Name,
                    $Option.Name,
                    'ParameterName',
                    $Option.Value
                )
            }
        }
        return
    }

    Complete-YsdPath $WordToComplete $true
}.GetNewClosure()

$Register = Get-Command Register-ArgumentCompleter
if ($Register.Parameters.ContainsKey('Native')) {
    Register-ArgumentCompleter -Native -CommandName ysd `
        -ScriptBlock $YsdCompletion
}
else {
    $YsdLegacyCompletion = {
        param(
            $CommandName,
            $ParameterName,
            $WordToComplete,
            $CommandAst,
            $FakeBoundParameters
        )
        & $YsdCompletion $WordToComplete $CommandAst
    }.GetNewClosure()
    Register-ArgumentCompleter -CommandName ysd `
        -ScriptBlock $YsdLegacyCompletion
    Remove-Variable YsdLegacyCompletion
}
Remove-Variable Register, YsdCompletion
