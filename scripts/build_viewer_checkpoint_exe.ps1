[CmdletBinding()]
param(
    [string]$CompilerPath = 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe',
    [string]$BasePath = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$inputScript = Join-Path $repositoryRoot 'tests\windows\generated\mxnm_viewer_adaptive_checkpoint1_standalone.ahk'
$outputDirectory = Join-Path $repositoryRoot 'publish-field'
$buildingExe = Join-Path $outputDirectory 'MxNM-Viewer-Checkpoint1.building.exe'
$finalExe = Join-Path $outputDirectory 'MxNM-Viewer-Checkpoint1.exe'
$hashFile = Join-Path $outputDirectory 'MxNM-Viewer-Checkpoint1.sha256.txt'
$iconPath = Join-Path $repositoryRoot 'assets\icon\generated\medex-icon.ico'

function Remove-BuildFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Remove-Item -LiteralPath $Path -Force
    }
}

try {
    foreach ($required in @(
        [pscustomobject]@{ Path = $CompilerPath; Name = 'Ahk2Exe compiler' },
        [pscustomobject]@{ Path = $BasePath; Name = 'AutoHotkey v2 base executable' },
        [pscustomobject]@{ Path = $inputScript; Name = 'Standalone checkpoint script' },
        [pscustomobject]@{ Path = $iconPath; Name = 'Application icon' }
    )) {
        if (-not (Test-Path -LiteralPath $required.Path -PathType Leaf)) {
            throw "$($required.Name) was not found: $($required.Path)"
        }
        if ((Get-Item -LiteralPath $required.Path).Length -le 0) {
            throw "$($required.Name) is empty: $($required.Path)"
        }
    }

    if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    Remove-BuildFile -Path $buildingExe

    $compileStartedUtc = [DateTime]::UtcNow
    $compilerArguments = @(
        '/in', ('"{0}"' -f $inputScript),
        '/out', ('"{0}"' -f $buildingExe),
        '/base', ('"{0}"' -f $BasePath),
        '/icon', ('"{0}"' -f $iconPath),
        '/silent', 'verbose'
    )
    $compilerProcess = Start-Process `
        -FilePath $CompilerPath `
        -ArgumentList $compilerArguments `
        -NoNewWindow `
        -Wait `
        -PassThru
    if ($compilerProcess.ExitCode -ne 0) {
        throw "Ahk2Exe failed with exit code $($compilerProcess.ExitCode)."
    }
    if (-not (Test-Path -LiteralPath $buildingExe -PathType Leaf)) {
        throw "Checkpoint executable was not created: $buildingExe"
    }
    $buildingItem = Get-Item -LiteralPath $buildingExe
    if ($buildingItem.Length -le 0) {
        throw "Checkpoint executable is empty: $buildingExe"
    }
    if ($buildingItem.LastWriteTimeUtc -lt $compileStartedUtc.AddSeconds(-2)) {
        throw "Checkpoint executable has a stale modification time: $buildingExe"
    }

    Move-Item -LiteralPath $buildingExe -Destination $finalExe -Force
    $finalItem = Get-Item -LiteralPath $finalExe
    if ($finalItem.Length -le 0) {
        throw "Final checkpoint executable is empty: $finalExe"
    }
    $hash = (Get-FileHash -LiteralPath $finalExe -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText(
        $hashFile,
        "$hash  MxNM-Viewer-Checkpoint1.exe`r`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host '================================'
    Write-Host 'Viewer checkpoint EXE build succeeded.' -ForegroundColor Green
    Write-Host "Artifact: $finalExe"
    Write-Host "SHA256:   $hash"
    Write-Host 'Only the EXE needs to be copied to target machines.'
    Write-Host '================================'
    exit 0
}
catch {
    Remove-BuildFile -Path $buildingExe
    Write-Host '================================'
    Write-Host 'Viewer checkpoint EXE build failed.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host '================================'
    exit 1
}
