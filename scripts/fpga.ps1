[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("program", "build", "build-program")]
    [string]$Action = "program",

    [string]$Bitstream,
    [string]$BuildScript,
    [string]$VivadoPath,
    [string]$ExpectedPart = "*xc7a100t*",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$ScriptDirectory = Split-Path -Parent $PSCommandPath
$RepositoryDirectory = Split-Path -Parent $ScriptDirectory
$DefaultBitstream = Join-Path $RepositoryDirectory "artifacts\bitstreams\optical_dsp_top.bit"
$DefaultBuildScript = Join-Path $ScriptDirectory "build_bitstream.tcl"
$ProgramScript = Join-Path $ScriptDirectory "program_device.tcl"
$ArtifactLogDirectory = Join-Path $RepositoryDirectory "artifacts\logs"

function Resolve-ExistingFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description does not exist: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

function Resolve-VivadoExecutable {
    param([string]$ExplicitPath)

    $Candidates = [System.Collections.Generic.List[string]]::new()

    if ($ExplicitPath) {
        $ExpandedExplicitPath = [Environment]::ExpandEnvironmentVariables($ExplicitPath)
        if (-not (Test-Path -LiteralPath $ExpandedExplicitPath -PathType Leaf)) {
            throw "Explicit Vivado executable does not exist: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExpandedExplicitPath).Path
    }

    if ($env:VIVADO_BIN) {
        $Candidates.Add($env:VIVADO_BIN)
    }

    foreach ($CommandName in @("vivado.bat", "vivado")) {
        $Command = Get-Command $CommandName -ErrorAction SilentlyContinue
        if ($Command) {
            $Candidates.Add($Command.Source)
        }
    }

    $InstallPatterns = @(
        "C:\AMDDesignTools\*\Vivado\bin\vivado.bat",
        "C:\AMDDesignTools\Vivado\*\bin\vivado.bat",
        "C:\AMDDesignTools\Vivado\bin\vivado.bat",
        "C:\Xilinx\Vivado\*\bin\vivado.bat",
        "C:\Xilinx\Vivado\bin\vivado.bat"
    )

    $DiscoveredExecutables = foreach ($InstallPattern in $InstallPatterns) {
        Get-Item -Path $InstallPattern -ErrorAction SilentlyContinue
    }

    foreach ($Executable in ($DiscoveredExecutables | Sort-Object FullName -Descending)) {
        $Candidates.Add($Executable.FullName)
    }

    foreach ($Candidate in $Candidates) {
        if (-not $Candidate) {
            continue
        }

        $ExpandedCandidate = [Environment]::ExpandEnvironmentVariables($Candidate)
        if (Test-Path -LiteralPath $ExpandedCandidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $ExpandedCandidate).Path
        }
    }

    throw @"
Vivado was not found. Supply -VivadoPath, add vivado.bat to PATH, or set
VIVADO_BIN to the full Vivado executable path.
"@
}

function Invoke-VivadoBatch {
    param(
        [Parameter(Mandatory)]
        [string]$Vivado,
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$StepName,
        [string[]]$TclArguments = @()
    )

    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $LogPath = Join-Path $ArtifactLogDirectory "$Timestamp-$StepName.log"
    $JournalPath = Join-Path $ArtifactLogDirectory "$Timestamp-$StepName.jou"
    $Arguments = @(
        "-mode", "batch",
        "-source", $Source,
        "-log", $LogPath,
        "-journal", $JournalPath
    )

    if ($TclArguments.Count -gt 0) {
        $Arguments += "-tclargs"
        $Arguments += $TclArguments
    }

    Write-Host "Vivado:  $Vivado"
    Write-Host "Step:    $StepName"
    Write-Host "Source:  $Source"
    Write-Host "Workdir: $RepositoryDirectory"
    Write-Host "Log:     $LogPath"

    if ($DryRun) {
        $DisplayArguments = $Arguments | ForEach-Object {
            if ($_ -match "\s") { '"{0}"' -f $_ } else { $_ }
        }
        Write-Host "DRY RUN: `"$Vivado`" $($DisplayArguments -join ' ')"
        return
    }

    # Vivado loads user Tcl apps before reading HDL. Keep batch builds isolated
    # from optional GUI-installed apps, and use an 8.3 path because the Tcl App
    # Store mishandles spaces in Windows profile paths.
    $VivadoProfileDirectory = Join-Path $RepositoryDirectory "artifacts\vivado-profile"
    $VivadoRoamingDirectory = Join-Path $VivadoProfileDirectory "AppData\Roaming"
    New-Item -ItemType Directory -Path $VivadoRoamingDirectory -Force | Out-Null

    $FileSystemObject = New-Object -ComObject Scripting.FileSystemObject
    $VivadoProfilePath = $FileSystemObject.GetFolder($VivadoProfileDirectory).ShortPath
    $VivadoRoamingPath = $FileSystemObject.GetFolder($VivadoRoamingDirectory).ShortPath

    $SavedUserProfile = $env:USERPROFILE
    $SavedAppData = $env:APPDATA

    Push-Location $RepositoryDirectory
    try {
        $env:USERPROFILE = $VivadoProfilePath
        $env:APPDATA = $VivadoRoamingPath

        & $Vivado @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Vivado $StepName failed with exit code $LASTEXITCODE. See $LogPath"
        }
    }
    finally {
        $env:USERPROFILE = $SavedUserProfile
        $env:APPDATA = $SavedAppData
        Pop-Location
    }
}

$ResolvedVivado = Resolve-VivadoExecutable -ExplicitPath $VivadoPath

if (-not $DryRun -and -not (Test-Path -LiteralPath $ArtifactLogDirectory)) {
    New-Item -ItemType Directory -Path $ArtifactLogDirectory -Force | Out-Null
}

if ($Action -in @("build", "build-program")) {
    $SelectedBuildScript = if ($BuildScript) { $BuildScript } else { $DefaultBuildScript }
    $ResolvedBuildScript = Resolve-ExistingFile -Path $SelectedBuildScript -Description "Build Tcl script"
    Invoke-VivadoBatch -Vivado $ResolvedVivado -Source $ResolvedBuildScript -StepName "build"
}

if ($Action -in @("program", "build-program")) {
    $SelectedBitstream = if ($Bitstream) { $Bitstream } else { $DefaultBitstream }
    $ResolvedBitstream = Resolve-ExistingFile -Path $SelectedBitstream -Description "Bitstream"
    $ResolvedProgramScript = Resolve-ExistingFile -Path $ProgramScript -Description "Programming Tcl script"

    if ([System.IO.Path]::GetExtension($ResolvedBitstream) -ne ".bit") {
        throw "Expected a .bit file, got: $ResolvedBitstream"
    }

    Invoke-VivadoBatch `
        -Vivado $ResolvedVivado `
        -Source $ResolvedProgramScript `
        -StepName "program" `
        -TclArguments @($ResolvedBitstream, $ExpectedPart)
}

Write-Host "FPGA action '$Action' completed successfully."
