[CmdletBinding()]
param(
    [string]$Text = '',
    [ValidateSet('Text', 'Voice', 'Attachment', 'Mixed')]
    [string]$InputType = 'Text',
    [string[]]$AttachmentPath = @(),
    [string]$Title,
    [string]$Source = 'chat',
    [string]$KnowledgeHubRoot
)

$ErrorActionPreference = 'Stop'

if (-not $KnowledgeHubRoot -and $env:KNOWLEDGE_HUB_ROOT) {
    $KnowledgeHubRoot = $env:KNOWLEDGE_HUB_ROOT
}
if (-not $KnowledgeHubRoot) {
    throw 'KnowledgeHub root was not provided and could not be discovered.'
}
$KnowledgeHubRoot = (Resolve-Path -LiteralPath $KnowledgeHubRoot).Path
if (-not (Test-Path -LiteralPath (Join-Path $KnowledgeHubRoot '00-Inbox\Human') -PathType Container)) {
    throw 'The selected directory is not a compatible KnowledgeHub.'
}
if (-not $Text.Trim() -and $AttachmentPath.Count -eq 0) {
    throw 'A capture requires text or at least one attachment.'
}

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Escape-YamlDoubleQuoted {
    param([string]$Value)
    return $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '').Replace("`n", ' ')
}

$now = Get-Date
$captureKey = $now.ToString('yyyyMMdd-HHmmss-fff') + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 8))
$year = $now.ToString('yyyy')
$month = $now.ToString('MM')
$recordDirectory = Join-Path $KnowledgeHubRoot "00-Inbox\Human\Quick-Captures\$year\$month"
$assetDirectory = Join-Path $KnowledgeHubRoot "10-Sources\Attachments\Quick-Captures\$year\$month\$captureKey"
$recordPath = Join-Path $recordDirectory "$captureKey.md"

if (-not $Title) {
    $Title = 'Quick capture ' + $now.ToString('yyyy-MM-dd HH:mm:ss')
}

$attachmentLines = [System.Collections.Generic.List[string]]::new()
$copiedAttachments = [System.Collections.Generic.List[object]]::new()
foreach ($item in $AttachmentPath) {
    $sourcePath = (Resolve-Path -LiteralPath $item).Path
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Attachment is not a file: $sourcePath"
    }
    New-Item -ItemType Directory -Force -Path $assetDirectory | Out-Null
    $destinationName = [IO.Path]::GetFileName($sourcePath)
    $destinationPath = Join-Path $assetDirectory $destinationName
    if (Test-Path -LiteralPath $destinationPath) {
        $baseName = [IO.Path]::GetFileNameWithoutExtension($destinationName)
        $extension = [IO.Path]::GetExtension($destinationName)
        $destinationName = "$baseName-$([guid]::NewGuid().ToString('N').Substring(0, 8))$extension"
        $destinationPath = Join-Path $assetDirectory $destinationName
    }
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destinationPath).Hash.ToLowerInvariant()
    $relativePath = $destinationPath.Substring($KnowledgeHubRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
    $attachmentLines.Add("- [[$relativePath]] - SHA256: $hash")
    $copiedAttachments.Add([pscustomobject]@{ path = $relativePath; sha256 = $hash })
}
if ($attachmentLines.Count -eq 0) { $attachmentLines.Add('- None') }

$templatePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\capture-template.md'
$content = Get-Content -Raw -Encoding UTF8 -LiteralPath $templatePath
$safeText = if ($Text.Trim()) { $Text.Trim() } else { '(No reliable transcript or text was available.)' }
$content = $content.Replace('{{ID}}', "note/quick-capture/$captureKey")
$content = $content.Replace('{{TITLE}}', (Escape-YamlDoubleQuoted $Title))
$content = $content.Replace('{{CREATED_AT}}', $now.ToString('o'))
$content = $content.Replace('{{INPUT_TYPE}}', $InputType.ToLowerInvariant())
$content = $content.Replace('{{SOURCE}}', (Escape-YamlDoubleQuoted $Source))
$content = $content.Replace('{{ATTACHMENTS}}', ($attachmentLines -join [Environment]::NewLine))
$content = $content.Replace('{{TEXT}}', $safeText)
Write-Utf8File -Path $recordPath -Content $content

$relativeRecord = $recordPath.Substring($KnowledgeHubRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
[pscustomobject]@{
    id = "note/quick-capture/$captureKey"
    record = $relativeRecord
    attachments = $copiedAttachments
    processing_state = 'captured'
    summarized = $false
    archived = $false
    git_action = 'none'
} | ConvertTo-Json -Depth 6
