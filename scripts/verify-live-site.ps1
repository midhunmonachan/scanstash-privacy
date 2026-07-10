[CmdletBinding()]
param(
    [string]$SiteUrl = 'https://midhunmonachan.github.io/scanstash-privacy/',

    [ValidateRange(10, 900)]
    [int]$TimeoutSeconds = 600
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$lastFailure = 'No request attempted.'

do {
    try {
        $response = Invoke-WebRequest `
            -Uri $SiteUrl `
            -UseBasicParsing `
            -Headers @{ 'Cache-Control' = 'no-cache' }

        if ($response.StatusCode -ne 200) {
            throw "Unexpected site status: $($response.StatusCode)"
        }
        if ($response.BaseResponse.ResponseUri.Scheme -ne 'https') {
            throw 'Live policy did not resolve over HTTPS.'
        }
        if ($response.Headers['Content-Type'] -notmatch 'text/html') {
            throw "Unexpected policy content type: $($response.Headers['Content-Type'])"
        }
        foreach ($requiredText in @(
            '<title>ScanStash Privacy Policy</title>',
            'Your receipts stay under your control.',
            'Open a privacy inquiry'
        )) {
            if (-not $response.Content.Contains($requiredText)) {
                throw "Live policy content missing: $requiredText"
            }
        }
        foreach ($forbiddenText in @('TBD', 'TODO', '{{')) {
            if ($response.Content.Contains($forbiddenText)) {
                throw "Live policy contains placeholder text: $forbiddenText"
            }
        }

        $assets = @(
            [System.Uri]::new([System.Uri]$SiteUrl, 'styles.css').AbsoluteUri,
            [System.Uri]::new([System.Uri]$SiteUrl, 'assets/scanstash-icon.png').AbsoluteUri,
            'https://github.com/midhunmonachan/scanstash-privacy/issues/new'
        )
        foreach ($assetUrl in $assets) {
            $assetResponse = Invoke-WebRequest `
                -Uri $assetUrl `
                -UseBasicParsing `
                -Headers @{ 'Cache-Control' = 'no-cache' }
            if ($assetResponse.StatusCode -ne 200) {
                throw "Live dependency returned $($assetResponse.StatusCode): $assetUrl"
            }
        }

        [pscustomobject]@{
            SiteUrl = $SiteUrl
            Status = 'PASS'
            Https = $true
            Html = '200 text/html'
            DependenciesVerified = $assets.Count
        }
        exit 0
    } catch {
        $lastFailure = $_.Exception.Message
        if ((Get-Date) -ge $deadline) {
            break
        }
        Start-Sleep -Seconds 10
    }
} while ((Get-Date) -lt $deadline)

throw "Live ScanStash privacy site did not verify within $TimeoutSeconds seconds: $lastFailure"
