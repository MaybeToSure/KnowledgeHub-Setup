[CmdletBinding()]
param(
    [ValidateSet('GitHub', 'Local', 'Existing')]
    [string]$Mode = 'Local',
    [string]$Destination,
    [string]$GitHubRepository,
    [string]$KnowledgeRepositoryUrl,
    [string]$TemplateRepository = 'MaybeToSure/KnowledgeHub-Framework'
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
    $documents = [Environment]::GetFolderPath('MyDocuments')
    $Destination = Join-Path $documents 'KnowledgeHub'
}
$Destination = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $Destination) {
    if (@(Get-ChildItem -LiteralPath $Destination -Force -ErrorAction Stop).Count -gt 0) {
        throw "Destination is not empty: $Destination"
    }
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
}

$lfsPullCompleted = $false
if ($Mode -eq 'GitHub') {
    Assert-Command -Name 'gh' -InstallHint 'Install GitHub CLI and authenticate, then run this script again.'
    if ($GitHubRepository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        throw 'GitHub mode requires -GitHubRepository in owner/repository format.'
    }
    & gh auth status | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI is not authenticated.' }
    & gh repo create $GitHubRepository --private --template $TemplateRepository
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the private GitHub repository. It may already exist.' }
    $KnowledgeRepositoryUrl = "https://github.com/$GitHubRepository.git"
    & git clone -- $KnowledgeRepositoryUrl $Destination
    if ($LASTEXITCODE -ne 0) { throw 'The new private repository was created, but cloning it failed.' }
    & git -C $Destination lfs pull
    if ($LASTEXITCODE -ne 0) { throw 'Git LFS pull failed.' }
    $lfsPullCompleted = $true
} elseif ($Mode -eq 'Existing') {
    if (-not $KnowledgeRepositoryUrl) { throw 'Existing mode requires -KnowledgeRepositoryUrl.' }
    Assert-SafeRepositoryUrl -Url $KnowledgeRepositoryUrl
    & git clone -- $KnowledgeRepositoryUrl $Destination
    if ($LASTEXITCODE -ne 0) { throw 'Knowledge repository clone failed.' }
    & git -C $Destination lfs pull
    if ($LASTEXITCODE -ne 0) { throw 'Git LFS pull failed.' }
    $lfsPullCompleted = $true
} else {
    $templateUrl = "https://github.com/$TemplateRepository.git"
    Assert-SafeRepositoryUrl -Url $templateUrl
    & git clone -- $templateUrl $Destination
    if ($LASTEXITCODE -ne 0) { throw 'Framework clone failed.' }
    & git -C $Destination remote rename origin framework
    if ($LASTEXITCODE -ne 0) { throw 'Could not rename the framework remote.' }
}

$setupScript = Join-Path $Destination 'tools\setup.ps1'
$verifyScript = Join-Path $Destination 'tools\verify-repository.ps1'
if (-not (Test-Path -LiteralPath $setupScript -PathType Leaf)) { throw 'The instance does not contain tools/setup.ps1.' }
if (-not (Test-Path -LiteralPath $verifyScript -PathType Leaf)) { throw 'The instance does not contain tools/verify-repository.ps1.' }

& $setupScript -Root $Destination | Out-Null
& $verifyScript -Root $Destination | Out-Null

$remotes = @(& git -C $Destination remote)
[pscustomobject]@{
    mode = $Mode
    destination = $Destination
    setup_completed = $true
    verification_completed = $true
    lfs_pull_completed = $lfsPullCompleted
    personal_origin_configured = ($remotes -contains 'origin')
    framework_remote_configured = ($remotes -contains 'framework')
    head = (& git -C $Destination rev-parse HEAD)
} | ConvertTo-Json -Depth 5
