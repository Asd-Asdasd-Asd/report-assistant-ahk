[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageScript = Join-Path $PSScriptRoot 'package_release.py'

function Resolve-PythonCommand {
    $candidates = @(
        [pscustomobject]@{ Name = 'py.exe'; PrefixArguments = @('-3') },
        [pscustomobject]@{ Name = 'python.exe'; PrefixArguments = @() },
        [pscustomobject]@{ Name = 'python3.exe'; PrefixArguments = @() }
    )

    foreach ($candidate in $candidates) {
        $command = Get-Command `
            $candidate.Name `
            -CommandType Application `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($null -eq $command) {
            continue
        }
        try {
            $versionArguments = @(
                $candidate.PrefixArguments
            ) + @('--version')
            & $command.Source @versionArguments *> $null
            if ($LASTEXITCODE -eq 0) {
                return [pscustomobject]@{
                    Executable = $command.Source
                    PrefixArguments = @($candidate.PrefixArguments)
                }
            }
        }
        catch {
            continue
        }
    }
    throw 'Python 3 was not found. Install Python or make py.exe/python.exe available on PATH.'
}

try {
    if (-not (Test-Path -LiteralPath $packageScript -PathType Leaf)) {
        throw "Release packager was not found: $packageScript"
    }
    $python = Resolve-PythonCommand
    $arguments = @($python.PrefixArguments) + @($packageScript)
    & $python.Executable @arguments
    exit $LASTEXITCODE
}
catch {
    Write-Host 'PACKAGING FAILED' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
