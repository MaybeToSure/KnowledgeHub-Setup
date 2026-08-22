[CmdletBinding()]
param(
    [string]$TargetRoot = "$env:USERPROFILE\.codex\skills",
    [switch]$Replace
)

$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'knowledge-hub-bootstrap'
$target = Join-Path $TargetRoot 'knowledge-hub-bootstrap'
if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md') -PathType Leaf)) {
    throw 'The deployment package is missing knowledge-hub-bootstrap/SKILL.md.'
}

New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
if (Test-Path -LiteralPath $target) {
    if (-not $Replace) { throw "Skill already exists: $target. Re-run with -Replace to install a new version." }
    $backup = "$target.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Move-Item -LiteralPath $target -Destination $backup
}

Copy-Item -LiteralPath $source -Destination $target -Recurse
[pscustomobject]@{
    installed = $true
    source = $source
    target = $target
    restart_codex = $true
} | ConvertTo-Json -Depth 5
