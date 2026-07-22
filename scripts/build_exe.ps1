[CmdletBinding()]
param(
    [string]$CompilerPath = 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe',
    [string]$BasePath = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$buildReleaseScript = Join-Path $PSScriptRoot 'build_release.py'
$releaseScript = Join-Path $repositoryRoot 'release\report_assistant.ahk'
$publishDirectory = Join-Path $repositoryRoot 'publish'
$publishAssetsDirectory = Join-Path $repositoryRoot 'assets\publish'
$buildingExe = Join-Path $publishDirectory '麦旋风.building.exe'
$previousExe = Join-Path $publishDirectory '麦旋风.previous.exe'
$finalExe = Join-Path $publishDirectory '麦旋风.exe'
$displayArtifactPath = 'publish\麦旋风.exe'

$stage = 'initialization'
$promotionStarted = $false
$finalCreatedByCurrentBuild = $false
$hadExistingFinal = $false
$originalFinalHash = $null
$compileStartedUtc = $null
$compilerStdoutLog = $null
$compilerStderrLog = $null

function Remove-ManagedFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Attempts = 5,
        [int]$RetryDelayMs = 250
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return
        }
        try {
            Remove-Item -LiteralPath $Path -Force
            return
        }
        catch {
            if ($attempt -eq $Attempts) {
                throw "Unable to remove build-managed file after $Attempts attempts. Exit any running Ahk2Exe or MedEx Report Assistant process using this file: $Path. $($_.Exception.Message)"
            }
            Start-Sleep -Milliseconds $RetryDelayMs
        }
    }
}

function Remove-TemporaryLog {
    param([string]$Path)

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    }
}

function Write-CompilerOutput {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }
    $content = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if (-not [string]::IsNullOrWhiteSpace($content)) {
        Write-Host "${Label}:"
        Write-Host $content.TrimEnd() -ForegroundColor $Color
    }
}

function Resolve-PythonCommand {
    $candidates = @(
        [pscustomobject]@{ Name = 'py.exe'; PrefixArguments = @('-3') },
        [pscustomobject]@{ Name = 'python.exe'; PrefixArguments = @() },
        [pscustomobject]@{ Name = 'python3.exe'; PrefixArguments = @() }
    )

    foreach ($candidate in $candidates) {
        $command = Get-Command $candidate.Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $command) {
            continue
        }
        try {
            $versionArguments = @($candidate.PrefixArguments) + @('--version')
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

function Assert-RecentNonemptyFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][datetime]$NotBeforeUtc,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description was not created: $Path"
    }
    $item = Get-Item -LiteralPath $Path
    if ($item.Length -le 0) {
        throw "$Description is empty: $Path"
    }
    if ($item.LastWriteTimeUtc -lt $NotBeforeUtc.AddSeconds(-2)) {
        throw "$Description has a stale modification time: $Path"
    }
    return $item
}

function Copy-PublishAssets {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDirectory,
        [Parameter(Mandatory = $true)][string]$DestinationDirectory
    )

    Write-Host "Static asset source: $SourceDirectory"
    Write-Host "Static asset destination: $DestinationDirectory"

    if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
        Write-Host 'No assets/publish directory was found; skipping static resource sync.'
        return 0
    }

    $sourceRoot = (Get-Item -LiteralPath $SourceDirectory).FullName.TrimEnd('\')
    $files = Get-ChildItem -LiteralPath $SourceDirectory -Force -Recurse -File
    $copiedCount = 0
    foreach ($item in $files) {
        $relativePath = $item.FullName.Substring($sourceRoot.Length).TrimStart('\')
        $destinationPath = Join-Path $DestinationDirectory $relativePath
        $destinationParent = Split-Path -Parent $destinationPath
        if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
            New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        }
        Copy-Item -LiteralPath $item.FullName -Destination $destinationPath -Force
        if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
            throw "Static publish asset was not copied: $relativePath"
        }
        $sourceHash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        $destinationHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash
        if ($sourceHash -ne $destinationHash) {
            throw "Static publish asset validation failed: $relativePath"
        }
        $copiedCount++
        Write-Host "  Copied: $relativePath"
    }
    return $copiedCount
}

function Restore-InterruptedPromotion {
    if (-not (Test-Path -LiteralPath $previousExe -PathType Leaf)) {
        return
    }

    Write-Host 'Recovering the previous final artifact from an interrupted promotion.' -ForegroundColor Yellow
    Remove-ManagedFile -Path $finalExe
    Move-Item -LiteralPath $previousExe -Destination $finalExe
}

function Restore-LastKnownGoodFinal {
    if (Test-Path -LiteralPath $previousExe -PathType Leaf) {
        Remove-ManagedFile -Path $finalExe
        Move-Item -LiteralPath $previousExe -Destination $finalExe
        return
    }

    if ($finalCreatedByCurrentBuild -and -not $hadExistingFinal) {
        Remove-ManagedFile -Path $finalExe
        return
    }

    if ($hadExistingFinal -and (Test-Path -LiteralPath $finalExe -PathType Leaf)) {
        $currentHash = (Get-FileHash -LiteralPath $finalExe -Algorithm SHA256).Hash
        if ($currentHash -eq $originalFinalHash) {
            return
        }
    }

    if ($promotionStarted) {
        throw 'Promotion failed and the last-known-good final artifact could not be restored automatically.'
    }
}

try {
    $stage = 'prepare publish directory'
    if (-not (Test-Path -LiteralPath $publishDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $publishDirectory -Force | Out-Null
    }
    Restore-InterruptedPromotion
    Remove-ManagedFile -Path $buildingExe

    $stage = 'validate build prerequisites'
    if (-not (Test-Path -LiteralPath $buildReleaseScript -PathType Leaf)) {
        throw "Release generator was not found: $buildReleaseScript"
    }
    if (-not (Test-Path -LiteralPath $CompilerPath -PathType Leaf)) {
        throw "Ahk2Exe compiler was not found: $CompilerPath"
    }
    if (-not (Test-Path -LiteralPath $BasePath -PathType Leaf)) {
        throw "AutoHotkey v2 64-bit base executable was not found: $BasePath"
    }
    $python = Resolve-PythonCommand

    $stage = 'generate release script'
    $releaseStartedUtc = [DateTime]::UtcNow
    $pythonArguments = @($python.PrefixArguments) + @($buildReleaseScript)
    & $python.Executable @pythonArguments
    if ($LASTEXITCODE -ne 0) {
        throw "build_release.py failed with exit code $LASTEXITCODE."
    }
    Assert-RecentNonemptyFile -Path $releaseScript -NotBeforeUtc $releaseStartedUtc -Description 'Generated release script' | Out-Null

    $stage = 'compile temporary executable'
    $compileStartedUtc = [DateTime]::UtcNow
    $compilerArguments = @(
        '/in', ('"{0}"' -f $releaseScript),
        '/out', ('"{0}"' -f $buildingExe),
        '/base', ('"{0}"' -f $BasePath),
        '/silent', 'verbose'
    )
    $compilerStdoutLog = [System.IO.Path]::GetTempFileName()
    $compilerStderrLog = [System.IO.Path]::GetTempFileName()
    $compilerProcess = Start-Process `
        -FilePath $CompilerPath `
        -ArgumentList $compilerArguments `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $compilerStdoutLog `
        -RedirectStandardError $compilerStderrLog
    $compilerExitCode = $compilerProcess.ExitCode
    Write-CompilerOutput -Path $compilerStdoutLog -Label 'Ahk2Exe output'
    Write-CompilerOutput -Path $compilerStderrLog -Label 'Ahk2Exe error output' -Color Red
    if ($compilerExitCode -ne 0) {
        throw "Ahk2Exe failed with exit code $compilerExitCode."
    }

    $stage = 'validate temporary executable'
    Assert-RecentNonemptyFile -Path $buildingExe -NotBeforeUtc $compileStartedUtc -Description 'Temporary executable' | Out-Null

    $stage = 'synchronize static publish assets'
    $assetCount = Copy-PublishAssets -SourceDirectory $publishAssetsDirectory -DestinationDirectory $publishDirectory
    Write-Host "Synchronized $assetCount static publish asset(s)."

    $stage = 'promote final executable'
    $hadExistingFinal = Test-Path -LiteralPath $finalExe -PathType Leaf
    if ($hadExistingFinal) {
        $originalFinalHash = (Get-FileHash -LiteralPath $finalExe -Algorithm SHA256).Hash
    }
    Remove-ManagedFile -Path $previousExe
    $promotionStarted = $true
    if ($hadExistingFinal) {
        [System.IO.File]::Replace($buildingExe, $finalExe, $previousExe, $false)
    }
    else {
        Move-Item -LiteralPath $buildingExe -Destination $finalExe
    }
    $finalCreatedByCurrentBuild = $true

    $stage = 'validate final executable'
    Assert-RecentNonemptyFile -Path $finalExe -NotBeforeUtc $compileStartedUtc -Description 'Final executable' | Out-Null

    $stage = 'complete promotion'
    Remove-ManagedFile -Path $previousExe
    $promotionStarted = $false

    Write-Host ''
    Write-Host '================================'
    Write-Host ''
    Write-Host 'Artifact:'
    Write-Host ''
    Write-Host $displayArtifactPath -ForegroundColor Green
    Write-Host ''
    Write-Host '================================'
    exit 0
}
catch {
    Write-Host ''
    Write-Host "BUILD FAILED [$stage]" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    try {
        Remove-ManagedFile -Path $buildingExe
        Restore-LastKnownGoodFinal
    }
    catch {
        Write-Host 'RECOVERY FAILED' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "Inspect: $buildingExe" -ForegroundColor Yellow
        Write-Host "Inspect: $previousExe" -ForegroundColor Yellow
        Write-Host "Inspect: $finalExe" -ForegroundColor Yellow
    }

    Write-Host 'The final artifact was not updated by a successful build.' -ForegroundColor Yellow
    exit 1
}
finally {
    Remove-TemporaryLog -Path $compilerStdoutLog
    Remove-TemporaryLog -Path $compilerStderrLog
}
