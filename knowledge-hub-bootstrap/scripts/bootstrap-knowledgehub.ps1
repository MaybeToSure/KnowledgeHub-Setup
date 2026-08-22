[CmdletBinding()]
param(
    [ValidateSet('New', 'Restore')]
    [string]$Mode = 'New',
    [string]$Destination,
    [string]$KnowledgeRepositoryUrl,
    [string]$FrameworkRepository = 'https://github.com/MaybeToSure/KnowledgeHub-Framework.git',
    [string]$FrameworkRef = 'main'
)

$ErrorActionPreference = 'Stop'

function Assert-Command {
    param([string]$Name, [string]$InstallHint)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found. $InstallHint"
    }
}

function Assert-SafeRepositoryUrl {
    param([string]$Url)
    if ($Url -match '^https?://[^/]+@') {
        throw 'Do not embed credentials in the repository URL. Use a credential manager, GitHub CLI, or SSH.'
    }
}

Assert-Command -Name 'git' -InstallHint 'Install Git, then run this script again.'
& git lfs version | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Git LFS is required. Install Git LFS, then run this script again.' }

if (-not $Destination) {
    if (Test-Path -LiteralPath 'D:\') {
        $Destination = 'D:\GitHub\KnowledgeHub'
    } else {
        $documents = [Environment]::GetFolderPath('MyDocuments')
        $Destination = Join-Path $documents 'KnowledgeHub'
    }
}
$Destination = [IO.Path]::GetFullPath($Destination)

if (Test-Path -LiteralPath $Destination) {
    $items = @(Get-ChildItem -LiteralPath $Destination -Force -ErrorAction Stop)
    if ($items.Count -gt 0) { throw "Destination is not empty: $Destination" }
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
}

$lfsPullCompleted = $false
if ($Mode -eq 'Restore') {
    if (-not $KnowledgeRepositoryUrl) { throw 'Restore mode requires -KnowledgeRepositoryUrl.' }
    Assert-SafeRepositoryUrl -Url $KnowledgeRepositoryUrl
    & git clone -- $KnowledgeRepositoryUrl $Destination
    if ($LASTEXITCODE -ne 0) { throw 'Knowledge repository clone failed.' }
    & git -C $Destination lfs pull
    if ($LASTEXITCODE -ne 0) { throw 'Git LFS pull failed.' }
    $lfsPullCompleted = $true
} else {
    Assert-SafeRepositoryUrl -Url $FrameworkRepository
    & git clone --branch $FrameworkRef -- $FrameworkRepository $Destination
    if ($LASTEXITCODE -ne 0) { throw 'Framework clone failed.' }
    & git -C $Destination remote rename origin framework
    if ($LASTEXITCODE -ne 0) { throw 'Could not rename the framework remote.' }
    & git -C $Destination switch -C main | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the local main branch.' }
}

$setupScript = Join-Path $Destination 'tools\setup.ps1'
$verifyScript = Join-Path $Destination 'tools\verify-repository.ps1'
if (-not (Test-Path -LiteralPath $setupScript -PathType Leaf)) { throw 'The repository does not contain tools/setup.ps1.' }
if (-not (Test-Path -LiteralPath $verifyScript -PathType Leaf)) { throw 'The repository does not contain tools/verify-repository.ps1.' }

& $setupScript -Root $Destination | Out-Null
& $verifyScript -Root $Destination | Out-Null

$remotes = @(& git -C $Destination remote)
[pscustomobject]@{
    mode = $Mode
    destination = $Destination
    setup_completed = $true
    verification_completed = $true
    lfs_pull_completed = $lfsPullCompleted
    origin_configured = ($remotes -contains 'origin')
    framework_remote_configured = ($remotes -contains 'framework')
    head = (& git -C $Destination rev-parse HEAD)
} | ConvertTo-Json -Depth 5
