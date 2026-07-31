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
$diagnosticRoot = Join-Path $buildRoot 'report-image-caption-diagnostic'
$sourceDirectory = Join-Path $diagnosticRoot 'source'
$publishDirectory = Join-Path $diagnosticRoot 'publish'
$generator = Join-Path $PSScriptRoot 'build_report_image_caption_diagnostic.py'
$inputScript = Join-Path $sourceDirectory 'report_image_caption_migration_diagnostic_standalone.ahk'
$buildingExe = Join-Path $publishDirectory 'MedEx-Report-Image-Caption-Diagnostic.building.exe'
$finalExe = Join-Path $publishDirectory 'MedEx-Report-Image-Caption-Diagnostic.exe'
$hashFile = Join-Path $publishDirectory 'MedEx-Report-Image-Caption-Diagnostic.sha256.txt'
$iconPath = Join-Path $repositoryRoot 'assets\icon\generated\medex-icon.ico'
$validationStdoutLog = $null
$validationStderrLog = $null
$compilerStdoutLog = $null
$compilerStderrLog = $null

function Write-ProcessOutput {
    param(
        [string]$Path,
        [Parameter(Mandatory = $true)][string]$Label,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or
        -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }
    $content = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if (-not [string]::IsNullOrWhiteSpace($content)) {
        Write-Host "${Label}:"
        Write-Host $content.TrimEnd() -ForegroundColor $Color
    }
}

function Remove-TemporaryLog {
    param([string]$Path)

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    }
}

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

try {
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

    $validationStdoutLog = [System.IO.Path]::GetTempFileName()
    $validationStderrLog = [System.IO.Path]::GetTempFileName()
    $validationProcess = Start-Process `
        -FilePath $BasePath `
        -ArgumentList @(
            '/ErrorStdOut',
            '/Validate',
            ('"{0}"' -f $inputScript)
        ) `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $validationStdoutLog `
        -RedirectStandardError $validationStderrLog
    Write-ProcessOutput -Path $validationStdoutLog -Label 'AutoHotkey validation output'
    Write-ProcessOutput -Path $validationStderrLog -Label 'AutoHotkey validation error' -Color Red
    if ($validationProcess.ExitCode -ne 0) {
        throw "AutoHotkey validation failed with exit code $($validationProcess.ExitCode)."
    }

    $compileStartedUtc = [DateTime]::UtcNow
    $compilerArguments = @(
        '/in', ('"{0}"' -f $inputScript),
        '/out', ('"{0}"' -f $buildingExe),
        '/base', ('"{0}"' -f $BasePath),
        '/icon', ('"{0}"' -f $iconPath),
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
    Write-ProcessOutput -Path $compilerStdoutLog -Label 'Ahk2Exe output'
    Write-ProcessOutput -Path $compilerStderrLog -Label 'Ahk2Exe error output' -Color Red
    if ($compilerProcess.ExitCode -ne 0) {
        throw "Ahk2Exe failed with exit code $($compilerProcess.ExitCode)."
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
        "$hash  MedEx-Report-Image-Caption-Diagnostic.exe`r`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host 'Report image caption diagnostic build succeeded.' -ForegroundColor Green
    Write-Host "Artifact: $finalExe"
    Write-Host "SHA256:   $hash"
    exit 0
}
catch {
    Write-ProcessOutput -Path $validationStdoutLog -Label 'AutoHotkey validation output'
    Write-ProcessOutput -Path $validationStderrLog -Label 'AutoHotkey validation error' -Color Red
    Write-ProcessOutput -Path $compilerStdoutLog -Label 'Ahk2Exe output'
    Write-ProcessOutput -Path $compilerStderrLog -Label 'Ahk2Exe error output' -Color Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
finally {
    Remove-TemporaryLog -Path $validationStdoutLog
    Remove-TemporaryLog -Path $validationStderrLog
    Remove-TemporaryLog -Path $compilerStdoutLog
    Remove-TemporaryLog -Path $compilerStderrLog
}
