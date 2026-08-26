param(
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version = '0.1.6',

    [string]$Prefix = (Join-Path $HOME '.local')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$OsArchitecture =
    [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture

$Architecture = switch ($OsArchitecture.ToString()) {
    'X64' { 'amd64' }
    'Arm64' { 'arm64' }
    default { throw "Unsupported architecture: $OsArchitecture" }
}

$Archive = "ysd-$Version-windows_$Architecture.zip"
$ReleaseRoot = 'https://github.com/yaml/yamlschema/releases/download'
$Url = "$ReleaseRoot/v$Version/$Archive"
$CompletionUrl = 'https://yamlschema.org/complete.ps1'
$TempDirectory = [IO.Path]::GetTempPath()
$Work = Join-Path $TempDirectory "yamlschema-$([guid]::NewGuid())"
$InstallDir = Join-Path $Prefix 'bin'
$ShareDir = Join-Path $Prefix 'share\yamlschema'
$ArchivePath = Join-Path $Work $Archive
$Executable = Join-Path $InstallDir 'ysd.exe'
$CompletionSource = Join-Path $Work 'complete.ps1'
$CompletionFile = Join-Path $ShareDir 'complete.ps1'

New-Item -ItemType Directory -Path $Work, $InstallDir, $ShareDir -Force |
    Out-Null

try {
    $Request = @{
        Uri = $Url
        OutFile = $ArchivePath
        UseBasicParsing = $true
    }
    Invoke-WebRequest @Request
    Invoke-WebRequest -Uri $CompletionUrl -OutFile $CompletionSource `
        -UseBasicParsing
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $Work

    $Package = Join-Path $Work "ysd-$Version-windows_$Architecture"
    Copy-Item (Join-Path $Package 'ysd.exe') $InstallDir -Force
    Copy-Item $CompletionSource $CompletionFile -Force
    Unblock-File $Executable
    Unblock-File $CompletionFile
}
finally {
    Remove-Item -LiteralPath $Work -Recurse -Force `
        -ErrorAction SilentlyContinue
}

$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$PathParts = @($UserPath -split ';' | Where-Object { $_ })

if ($PathParts -notcontains $InstallDir) {
    $NewUserPath = (($PathParts + $InstallDir) -join ';')
    [Environment]::SetEnvironmentVariable(
        'Path',
        $NewUserPath,
        'User'
    )
}

if (($env:Path -split ';') -notcontains $InstallDir) {
    $env:Path = "$InstallDir;$env:Path"
}

$ProfilePath = $PROFILE.CurrentUserAllHosts
$ProfileDirectory = Split-Path -Parent $ProfilePath
$EscapedCompletionFile = $CompletionFile.Replace("'", "''")
$ProfileLine = ". '$EscapedCompletionFile'"

New-Item -ItemType Directory -Path $ProfileDirectory -Force |
    Out-Null
$ProfileContent = if (Test-Path -LiteralPath $ProfilePath) {
    [IO.File]::ReadAllText($ProfilePath)
}
else {
    ''
}
$ProfileLines = @($ProfileContent -split '\r?\n')
if ($ProfileLines -notcontains $ProfileLine) {
    $Separator = if ($ProfileContent -and
        -not $ProfileContent.EndsWith("`n")) {
        "`r`n"
    }
    else {
        ''
    }
    [IO.File]::AppendAllText(
        $ProfilePath,
        "$Separator$ProfileLine`r`n"
    )
}

. $CompletionFile

Write-Host "Installed YAMLSchema to $Executable"
Write-Host "Enabled tab completion from $CompletionFile"
Write-Host "Updated PowerShell profile $ProfilePath"
& $Executable --version
