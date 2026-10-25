#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Writes the release zip of this fork and its SHA-256 file.

.DESCRIPTION
    The zip holds the files that publish.yml stages for the gallery: PSMutant.psd1, PSMutant.psm1,
    src, schemas, LICENSE and README.md, at its root. git archive writes it from the commit, so two
    builds of one commit give the same bytes and the same SHA-256.

    Run it on a clean checkout of the tag, for example v0.9.1-quindos.1.

.PARAMETER Release
    The fork release, such as quindos.1. The file is PSMutant-<ModuleVersion>-<Release>.zip.

.PARAMETER OutDir
    The folder for the zip and the .sha256 file. Defaults to dist beside the repository root.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidatePattern('^quindos\.\d+$')] [string]$Release,
    [string]$OutDir
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $root 'dist' }
if (git -C $root status --porcelain) { throw "The checkout at $root has changes. Build the package from a clean checkout of the tag." }

$manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $root 'PSMutant.psd1')
$name = "PSMutant-$($manifest.ModuleVersion)-$Release"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$zip = Join-Path $OutDir "$name.zip"
git -C $root archive --format=zip --output=$zip HEAD PSMutant.psd1 PSMutant.psm1 src schemas LICENSE README.md
if ($LASTEXITCODE -ne 0) { throw "git archive failed with exit code $LASTEXITCODE." }

$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$zip.sha256" -Value "$hash  $name.zip" -Encoding ascii -NoNewline
Write-Host "$zip"
Write-Host "SHA-256 $hash"
