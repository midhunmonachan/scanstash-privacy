[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$indexPath = Join-Path $root 'index.html'
$stylePath = Join-Path $root 'styles.css'
$iconPath = Join-Path $root 'assets\scanstash-icon.png'

foreach ($path in @($indexPath, $stylePath, $iconPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required site file not found: $path"
    }
}

$html = Get-Content -LiteralPath $indexPath -Raw
$styles = Get-Content -LiteralPath $stylePath -Raw

foreach ($forbidden in @('TBD', 'TODO', '{{', 'javascript:', 'http://')) {
    if ($html.Contains($forbidden)) {
        throw "Forbidden placeholder or unsafe value found in index.html: $forbidden"
    }
}

[xml]$document = $html
$namespace = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
$requiredIds = @(
    'policy',
    'information-heading',
    'use-heading',
    'storage-heading',
    'access-heading',
    'sharing-heading',
    'network-heading',
    'retention-heading',
    'changes-heading',
    'contact-heading'
)
foreach ($id in $requiredIds) {
    if ($null -eq $document.SelectSingleNode("//*[@id='$id']", $namespace)) {
        throw "Required policy section missing: $id"
    }
}

$title = $document.SelectSingleNode('//title', $namespace)
if ($null -eq $title -or $title.InnerText -ne 'ScanStash Privacy Policy') {
    throw 'Document title must be ScanStash Privacy Policy.'
}

$heading = $document.SelectSingleNode('//h1', $namespace)
if ($null -eq $heading -or [string]::IsNullOrWhiteSpace($heading.InnerText)) {
    throw 'Privacy policy must contain one non-empty h1.'
}

$contactLink = $document.SelectSingleNode("//a[@class='contact-link']", $namespace)
if ($null -eq $contactLink -or
    $contactLink.href -ne 'https://github.com/midhunmonachan/scanstash-privacy/issues/new') {
    throw 'Privacy inquiry link is missing or incorrect.'
}

$requiredPhrases = @(
    'No Internet permission',
    'app-private storage',
    'Android Photo Picker',
    'Retention and deletion',
    'Midhun Monachan'
)
foreach ($phrase in $requiredPhrases) {
    if (-not $html.Contains($phrase)) {
        throw "Required policy content missing: $phrase"
    }
}

if ($styles -match 'letter-spacing\s*:\s*-') {
    throw 'Negative letter spacing is not allowed.'
}
if ($styles -match '(?i)(linear|radial|conic)-gradient') {
    throw 'Decorative gradients are not allowed.'
}

Add-Type -AssemblyName System.Drawing
$icon = [System.Drawing.Image]::FromFile($iconPath)
try {
    if ($icon.Width -ne 512 -or $icon.Height -ne 512) {
        throw "App icon must be 512x512; found $($icon.Width)x$($icon.Height)."
    }
} finally {
    $icon.Dispose()
}

[pscustomobject]@{
    Title = $title.InnerText
    RequiredSections = $requiredIds.Count
    ContactMechanism = $contactLink.href
    JavaScriptRequired = $false
    Icon = '512x512 PNG'
    Status = 'PASS'
}
