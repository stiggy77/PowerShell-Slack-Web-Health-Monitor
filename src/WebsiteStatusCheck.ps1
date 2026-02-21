# WebsiteStatusCheck.ps1
# Website availability check with Slack alerts (no external dependencies)
# Built by BOT-Solutions — https://bot-solutions.co.uk

[CmdletBinding()]
param(
    # One or more URLs to check
    [Parameter(Mandatory = $false)]
    [string[]]$UrlsToCheck = @(
        "https://example.com",
        "https://example.org/health"
    ),

    # Friendly title shown in Slack
    [Parameter(Mandatory = $false)]
    [string]$SlackTitle = "Web Health: Website Status",

    # Your internal alert/reference number (purely informational)
    [Parameter(Mandatory = $false)]
    [int]$SlackAlertNum = 37,

    # Allow alerts outside business hours? (passed into SlackCanWeNag)
    [Parameter(Mandatory = $false)]
    [bool]$OutOfHours = $true,

    # Request timeout in seconds
    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 15,

    # If set, send an "all clear" message when everything is OK
    [Parameter(Mandatory = $false)]
    [switch]$NotifyOnSuccess
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module "$PSScriptRoot\SLACKpost.psm1" -Force

# TLS hardening
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$failures = New-Object System.Collections.Generic.List[string]

foreach ($url in $UrlsToCheck) {
    if ([string]::IsNullOrWhiteSpace($url)) { continue }

    try {
        $resp = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec $TimeoutSeconds -UseBasicParsing
        $code = [int]$resp.StatusCode

        if ($code -lt 200 -or $code -ge 400) {
            $failures.Add("❌ $url — HTTP $code")
        }
    }
    catch {
        $msg = $_.Exception.Message
        $failures.Add("❌ $url — $msg")
    }
}

$canAlert = SlackCanWeNag -alertNum $SlackAlertNum -outofHours $OutOfHours

if ($failures.Count -gt 0) {
    if ($canAlert) {
        $body = ($failures -join "`n") + "`n`nBuilt by BOT-Solutions — https://bot-solutions.co.uk"
        [void](SlackSend -title "$SlackTitle (Alert #$SlackAlertNum)" -text $body -iconEmoji ":rotating_light:")
    }
    exit 1
}
else {
    if ($NotifyOnSuccess -and $canAlert) {
        $body = "✅ All endpoints returned a healthy HTTP status.`n`nBuilt by BOT-Solutions — https://bot-solutions.co.uk"
        [void](SlackSend -title "$SlackTitle (Alert #$SlackAlertNum)" -text $body -iconEmoji ":white_check_mark:")
    }
    exit 0
}