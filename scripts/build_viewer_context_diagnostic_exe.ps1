[CmdletBinding()]
param(
    [string]$CompilerPath = 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe',
    [string]$BasePath = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot '..\report-assistant-build')
)
$diagnosticRoot = Join-Path $buildRoot 'viewer-context-diagnostic'
$sourceDirectory = Join-Path $diagnosticRoot 'source'
$publishDirectory = Join-Path $diagnosticRoot 'publish'
$generator = Join-Path $PSScriptRoot 'build_mxnm_context_menu_diagnostic.py'
$inputScript = Join-Path $sourceDirectory 'mxnm_context_menu_receiver_diagnostic_standalone.ahk'
$buildingExe = Join-Path $publishDirectory 'MxNM-Viewer-Context-Diagnostic.building.exe'
$finalExe = Join-Path $publishDirectory 'MxNM-Viewer-Context-Diagnostic.exe'
$hashFile = Join-Path $publishDirectory 'MxNM-Viewer-Context-Diagnostic.sha256.txt'
$iconPath = Join-Path $repositoryRoot 'assets\icon\generated\medex-icon.ico'

function Resolve-PythonCommand {
    foreach ($candidate in @(
        [pscustomobject]@{ Name = 'py.exe'; Prefix = @('-3') },
        [pscustomobject]@{ Name = 'python.exe'; Prefix = @() },
        [pscustomobject]@{ Name = 'python3.exe'; Prefix = @() }
    )) {
        $command = Get-Command $candidate.Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $command) {
            continue
        }
        $versionArguments = @($candidate.Prefix) + @('--version')
        & $command.Source @versionArguments *> $null
        if ($LASTEXITCODE -eq 0) {
            return [pscustomobject]@{
                Executable = $command.Source
                Prefix = @($candidate.Prefix)
            }
        }
    }
    throw 'Python 3 was not found.'
}

foreach ($required in @($CompilerPath, $BasePath, $generator, $iconPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required file was not found: $required"
    }
}

$python = Resolve-PythonCommand
$pythonArguments = @($python.Prefix) + @(
    $generator,
    '--output',
    $inputScript
)
& $python.Executable @pythonArguments
if ($LASTEXITCODE -ne 0) {
    throw "Diagnostic generator failed with exit code $LASTEXITCODE."
}

New-Item -ItemType Directory -Path $publishDirectory -Force | Out-Null
if (Test-Path -LiteralPath $buildingExe) {
    Remove-Item -LiteralPath $buildingExe -Force
}

& $BasePath '/ErrorStdOut' '/Validate' $inputScript
if ($LASTEXITCODE -ne 0) {
    throw "AutoHotkey validation failed with exit code $LASTEXITCODE."
}

$compileStartedUtc = [DateTime]::UtcNow
& $CompilerPath `
    '/in' $inputScript `
    '/out' $buildingExe `
    '/base' $BasePath `
    '/icon' $iconPath `
    '/silent' 'verbose'
if ($LASTEXITCODE -ne 0) {
    throw "Ahk2Exe failed with exit code $LASTEXITCODE."
}
if (-not (Test-Path -LiteralPath $buildingExe -PathType Leaf)) {
    throw "Diagnostic executable was not created: $buildingExe"
}
$buildingItem = Get-Item -LiteralPath $buildingExe
if ($buildingItem.Length -le 0 -or
    $buildingItem.LastWriteTimeUtc -lt $compileStartedUtc.AddSeconds(-2)) {
    throw 'Diagnostic executable is empty or stale.'
}

Move-Item -LiteralPath $buildingExe -Destination $finalExe -Force
$hash = (Get-FileHash -LiteralPath $finalExe -Algorithm SHA256).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText(
    $hashFile,
    "$hash  MxNM-Viewer-Context-Diagnostic.exe`r`n",
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host 'Viewer context diagnostic build succeeded.' -ForegroundColor Green
Write-Host "Artifact: $finalExe"
Write-Host "SHA256:   $hash"
