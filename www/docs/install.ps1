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
$TempDirectory = [IO.Path]::GetTempPath()
$Work = Join-Path $TempDirectory "yamlschema-$([guid]::NewGuid())"
$InstallDir = Join-Path $Prefix 'bin'
$ArchivePath = Join-Path $Work $Archive
$Executable = Join-Path $InstallDir 'ysd.exe'

New-Item -ItemType Directory -Path $Work, $InstallDir -Force |
    Out-Null

try {
    $Request = @{
        Uri = $Url
        OutFile = $ArchivePath
        UseBasicParsing = $true
    }
    Invoke-WebRequest @Request
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $Work

    $Package = Join-Path $Work "ysd-$Version-windows_$Architecture"
    Copy-Item (Join-Path $Package 'ysd.exe') $InstallDir -Force
    Unblock-File $Executable
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

Write-Host "Installed YAMLSchema to $Executable"
& $Executable --version
