[CmdletBinding()]
param(
    # Python generator in scripts/ that writes the standalone .ahk (accepts --output).
    [Parameter(Mandatory = $true)][string]$Generator,
    # File name of the generated standalone script.
    [Parameter(Mandatory = $true)][string]$InputScriptName,
    # Base name of the produced EXE and its .sha256.txt.
    [Parameter(Mandatory = $true)][string]$ToolName,
    # Sub-directory under ..\report-assistant-build that holds source/ and publish/.
    [Parameter(Mandatory = $true)][string]$BuildSubdirectory,
    [string]$CompilerPath = 'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe',
    [string]$BasePath = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
)

# Builds one field tool (diagnostic, checkpoint or regression) EXE.
# It never runs the release generator or touches the product EXE.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot '..\report-assistant-build')
)
$toolRoot = Join-Path $buildRoot $BuildSubdirectory
$sourceDirectory = Join-Path $toolRoot 'source'
$publishDirectory = Join-Path $toolRoot 'publish'
$generatorPath = Join-Path $PSScriptRoot $Generator
$inputScript = Join-Path $sourceDirectory $InputScriptName
$buildingExe = Join-Path $publishDirectory "$ToolName.building.exe"
$finalExe = Join-Path $publishDirectory "$ToolName.exe"
$hashFile = Join-Path $publishDirectory "$ToolName.sha256.txt"
$iconPath = Join-Path $repositoryRoot 'assets\icon\generated\medex-icon.ico'
$validationStdoutLog = $null
$validationStderrLog = $null
$compilerStdoutLog = $null
$compilerStderrLog = $null

function Remove-BuildFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Remove-Item -LiteralPath $Path -Force
    }
}

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

try {
    foreach ($required in @(
        [pscustomobject]@{ Path = $CompilerPath; Name = 'Ahk2Exe compiler' },
        [pscustomobject]@{ Path = $BasePath; Name = 'AutoHotkey v2 base executable' },
        [pscustomobject]@{ Path = $generatorPath; Name = 'Tool generator' },
        [pscustomobject]@{ Path = $iconPath; Name = 'Application icon' }
    )) {
        if (-not (Test-Path -LiteralPath $required.Path -PathType Leaf)) {
            throw "$($required.Name) was not found: $($required.Path)"
        }
        if ((Get-Item -LiteralPath $required.Path).Length -le 0) {
            throw "$($required.Name) is empty: $($required.Path)"
        }
    }

    $python = Resolve-PythonCommand
    $pythonArguments = @($python.PrefixArguments) + @(
        $generatorPath,
        '--output',
        $inputScript
    )
    & $python.Executable @pythonArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Tool generator failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $inputScript -PathType Leaf) -or
        (Get-Item -LiteralPath $inputScript).Length -le 0) {
        throw "Standalone script was not generated: $inputScript"
    }

    if (-not (Test-Path -LiteralPath $publishDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $publishDirectory -Force | Out-Null
    }
    Remove-BuildFile -Path $buildingExe

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
        throw "AutoHotkey /Validate failed with exit code $($validationProcess.ExitCode)."
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
        throw "Tool executable was not created: $buildingExe"
    }
    $buildingItem = Get-Item -LiteralPath $buildingExe
    if ($buildingItem.Length -le 0) {
        throw "Tool executable is empty: $buildingExe"
    }
    if ($buildingItem.LastWriteTimeUtc -lt $compileStartedUtc.AddSeconds(-2)) {
        throw "Tool executable has a stale modification time: $buildingExe"
    }

    Move-Item -LiteralPath $buildingExe -Destination $finalExe -Force
    $finalItem = Get-Item -LiteralPath $finalExe
    if ($finalItem.Length -le 0) {
        throw "Final tool executable is empty: $finalExe"
    }
    $hash = (Get-FileHash -LiteralPath $finalExe -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText(
        $hashFile,
        "$hash  $ToolName.exe`r`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host '================================'
    Write-Host "$ToolName build succeeded." -ForegroundColor Green
    Write-Host "Artifact: $finalExe"
    Write-Host "SHA256:   $hash"
    Write-Host 'Only the EXE needs to be copied to target machines.'
    Write-Host '================================'
    Remove-TemporaryLog -Path $validationStdoutLog
    Remove-TemporaryLog -Path $validationStderrLog
    Remove-TemporaryLog -Path $compilerStdoutLog
    Remove-TemporaryLog -Path $compilerStderrLog
    exit 0
}
catch {
    Remove-BuildFile -Path $buildingExe
    Write-ProcessOutput -Path $validationStdoutLog -Label 'AutoHotkey validation output'
    Write-ProcessOutput -Path $validationStderrLog -Label 'AutoHotkey validation error' -Color Red
    Write-ProcessOutput -Path $compilerStdoutLog -Label 'Ahk2Exe output'
    Write-ProcessOutput -Path $compilerStderrLog -Label 'Ahk2Exe error output' -Color Red
    Remove-TemporaryLog -Path $validationStdoutLog
    Remove-TemporaryLog -Path $validationStderrLog
    Remove-TemporaryLog -Path $compilerStdoutLog
    Remove-TemporaryLog -Path $compilerStderrLog
    Write-Host '================================'
    Write-Host "$ToolName build failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host '================================'
    exit 1
}
