[CmdletBinding()]
param(
    [ValidateSet('GitHub', 'Local', 'Existing')]
    [string]$Mode = 'Local',
    [string]$Destination,
    [string]$WorkspaceRoot,
    [string]$GitHubRepository,
    [string]$KnowledgeRepositoryUrl,
    [string]$TemplateRepository = 'MaybeToSure/KnowledgeHub-Framework',
    [string]$FrameworkRef = 'v0.4.1',
    [string]$ExpectedFrameworkVersion = '0.4.1',
    [string]$MinimumExistingFrameworkVersion = '0.4.0'
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

function New-PinnedFrameworkClone {
    param([string]$RepositoryUrl, [string]$Ref, [string]$Target, [string]$ExpectedVersion)

    & git clone --no-checkout -- $RepositoryUrl $Target
    if ($LASTEXITCODE -ne 0) { throw 'Framework repository clone failed.' }
    & git -C $Target switch --detach $Ref | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Framework ref was not found: '$Ref'." }

    $currentBranch = (@(& git -C $Target branch --show-current) -join '').Trim()
    if (-not $currentBranch) {
        & git -C $Target show-ref --verify --quiet refs/heads/main
        if ($LASTEXITCODE -eq 0) {
            & git -C $Target branch -f main HEAD | Out-Null
            if ($LASTEXITCODE -eq 0) { & git -C $Target switch main | Out-Null }
        } else {
            & git -C $Target switch -c main | Out-Null
        }
    } elseif ($currentBranch -ne 'main') {
        & git -C $Target branch -M main
    }
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the local main branch from the pinned framework release.' }
    $clonedVersionFile = Join-Path $Target 'VERSION'
    if (-not (Test-Path -LiteralPath $clonedVersionFile -PathType Leaf)) { throw 'The pinned framework does not contain VERSION.' }
    $clonedVersion = (Get-Content -Raw -LiteralPath $clonedVersionFile).Trim()
    if ($clonedVersion -ne $ExpectedVersion) {
        throw "Framework ref '$Ref' produced VERSION '$clonedVersion'; expected '$ExpectedVersion'."
    }
    & git -C $Target remote rename origin framework
    if ($LASTEXITCODE -ne 0) { throw 'Could not rename the framework remote.' }
    & git -C $Target config --unset-all branch.main.remote 2>$null
    & git -C $Target config --unset-all branch.main.merge 2>$null
    & git -C $Target remote set-url --push framework DISABLED
    if ($LASTEXITCODE -ne 0) { throw 'Could not disable pushes to the framework remote.' }
}

Assert-Command -Name 'git' -InstallHint 'Install Git, then run this script again.'
& git lfs version | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Git LFS is required. Install Git LFS, then run this script again.' }

if (-not $WorkspaceRoot) {
    if ($Destination) {
        $WorkspaceRoot = Split-Path -Parent ([IO.Path]::GetFullPath($Destination))
    } elseif ($env:KNOWLEDGE_HUB_WORKSPACE_ROOT) {
        $WorkspaceRoot = $env:KNOWLEDGE_HUB_WORKSPACE_ROOT
    } else {
        $WorkspaceRoot = Join-Path $env:USERPROFILE 'KnowledgeHub-Workspace'
    }
}
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
if (-not $Destination) {
    $Destination = Join-Path $WorkspaceRoot 'KnowledgeHub'
}
$Destination = [IO.Path]::GetFullPath($Destination)
$expectedDestination = [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot 'KnowledgeHub'))
if (-not $Destination.Equals($expectedDestination, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Destination must be <WorkspaceRoot>\KnowledgeHub. Destination: $Destination; WorkspaceRoot: $WorkspaceRoot"
}
if (Test-Path -LiteralPath $Destination) {
    if (@(Get-ChildItem -LiteralPath $Destination -Force -ErrorAction Stop).Count -gt 0) {
        throw "Destination is not empty: $Destination"
    }
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
}

$lfsPullCompleted = $false
$templateUrl = "https://github.com/$TemplateRepository.git"
Assert-SafeRepositoryUrl -Url $templateUrl
if ($Mode -eq 'GitHub') {
    Assert-Command -Name 'gh' -InstallHint 'Install GitHub CLI and authenticate, then run this script again.'
    if ($GitHubRepository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        throw 'GitHub mode requires -GitHubRepository in owner/repository format.'
    }
    & gh auth status | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI is not authenticated.' }
    & gh repo view $GitHubRepository --json nameWithOwner 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { throw "GitHub repository already exists: $GitHubRepository" }
    New-PinnedFrameworkClone -RepositoryUrl $templateUrl -Ref $FrameworkRef -Target $Destination -ExpectedVersion $ExpectedFrameworkVersion
    & gh repo create $GitHubRepository --private
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the private GitHub repository. It may already exist.' }
    $KnowledgeRepositoryUrl = "https://github.com/$GitHubRepository.git"
    & git -C $Destination remote add origin $KnowledgeRepositoryUrl
    if ($LASTEXITCODE -ne 0) { throw 'The private repository was created, but its origin remote could not be configured.' }
    & git -C $Destination push -u origin main
    if ($LASTEXITCODE -ne 0) { throw 'The private repository was created, but the pinned framework baseline could not be pushed.' }
    $visibility = (& gh repo view $GitHubRepository --json visibility --jq '.visibility').Trim()
    if ($LASTEXITCODE -ne 0 -or $visibility -ne 'PRIVATE') { throw 'The created GitHub repository could not be verified as private.' }
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
    New-PinnedFrameworkClone -RepositoryUrl $templateUrl -Ref $FrameworkRef -Target $Destination -ExpectedVersion $ExpectedFrameworkVersion
}

$setupScript = Join-Path $Destination 'tools\setup.ps1'
$verifyScript = Join-Path $Destination 'tools\verify-repository.ps1'
$versionFile = Join-Path $Destination 'VERSION'
if (-not (Test-Path -LiteralPath $setupScript -PathType Leaf)) { throw 'The instance does not contain tools/setup.ps1.' }
if (-not (Test-Path -LiteralPath $verifyScript -PathType Leaf)) { throw 'The instance does not contain tools/verify-repository.ps1.' }
if (-not (Test-Path -LiteralPath $versionFile -PathType Leaf)) { throw 'The instance does not contain VERSION.' }
$frameworkVersion = (Get-Content -Raw -LiteralPath $versionFile).Trim()
if ($Mode -eq 'Existing') {
    try { $parsedFrameworkVersion = [version]$frameworkVersion } catch { throw "The existing instance has an invalid VERSION: $frameworkVersion" }
    if ($parsedFrameworkVersion -lt [version]$MinimumExistingFrameworkVersion) {
        throw "Existing mode requires KnowledgeHub Framework $MinimumExistingFrameworkVersion or newer. Migrate the legacy instance first."
    }
} elseif ($frameworkVersion -ne $ExpectedFrameworkVersion) {
    throw "Framework ref '$FrameworkRef' produced VERSION '$frameworkVersion'; expected '$ExpectedFrameworkVersion'."
}

& $setupScript -Root $Destination -WorkspaceRoot $WorkspaceRoot | Out-Null
& $verifyScript -Root $Destination | Out-Null

$remotes = @(& git -C $Destination remote)
[pscustomobject]@{
    mode = $Mode
    workspace_root = $WorkspaceRoot
    destination = $Destination
    framework_ref = if ($Mode -eq 'Existing') { $null } else { $FrameworkRef }
    framework_version = $frameworkVersion
    setup_completed = $true
    verification_completed = $true
    lfs_pull_completed = $lfsPullCompleted
    personal_origin_configured = ($remotes -contains 'origin')
    framework_remote_configured = ($remotes -contains 'framework')
    head = (& git -C $Destination rev-parse HEAD)
} | ConvertTo-Json -Depth 5
