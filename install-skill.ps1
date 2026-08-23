[CmdletBinding()]
param(
    [string]$TargetRoot = "$env:USERPROFILE\.codex\skills",
    [switch]$Replace
)

$ErrorActionPreference = 'Stop'
$skillNames = @('knowledge-hub-setup', 'yunfei-quick-capture')
$installPlan = foreach ($skillName in $skillNames) {
    $source = Join-Path $PSScriptRoot $skillName
    $target = Join-Path $TargetRoot $skillName
    if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md') -PathType Leaf)) {
        throw "The package is missing $skillName/SKILL.md."
    }
    [pscustomobject]@{ name = $skillName; source = $source; target = $target }
}

$existingTargets = @($installPlan | Where-Object { Test-Path -LiteralPath $_.target })
if ($existingTargets.Count -gt 0 -and -not $Replace) {
    $paths = ($existingTargets.target -join ', ')
    throw "Skills already exist: $paths. Re-run with -Replace to install a new version."
}

New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
$backups = [System.Collections.Generic.List[string]]::new()
$installedTargets = [System.Collections.Generic.List[string]]::new()
foreach ($item in $installPlan) {
    if (Test-Path -LiteralPath $item.target) {
        $backup = "$($item.target).backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item -LiteralPath $item.target -Destination $backup
        $backups.Add($backup)
    }
    Copy-Item -LiteralPath $item.source -Destination $item.target -Recurse
    $installedTargets.Add($item.target)
}

[pscustomobject]@{
    installed = $true
    targets = @($installedTargets)
    backups = @($backups)
    restart_codex = $true
} | ConvertTo-Json -Depth 5
