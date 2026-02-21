# HTTPResponseTime.ps1
# Response time monitoring with Slack alerts (no external dependencies)
# Built by BOT-Solutions — https://bot-solutions.co.uk

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$UrlsToCheck = @(
        "https://example.com",
        "https://example.org/health"
    ),

    [Parameter(Mandatory = $false)]
    [int]$ResponseThresholdMs = 1000,

    [Parameter(Mandatory = $false)]
    [string]$SlackTitle = "Web Health: Response Time",

    [Parameter(Mandatory = $false)]
    [int]$SlackAlertNum = 38,

    [Parameter(Mandatory = $false)]
    [bool]$OutOfHours = $true,

    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module "$PSScriptRoot\SLACKpost.psm1" -Force
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$breaches = New-Object System.Collections.Generic.List[string]

foreach ($url in $UrlsToCheck) {
    if ([string]::IsNullOrWhiteSpace($url)) { continue }

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $null = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec $TimeoutSeconds -UseBasicParsing
        $sw.Stop()

        $ms = [int]$sw.ElapsedMilliseconds
        if ($ms -gt $ResponseThresholdMs) {
            $breaches.Add("⚠️ $url — ${ms}ms (threshold ${ResponseThresholdMs}ms)")
        }
    }
    catch {
        $msg = $_.Exception.Message
        $breaches.Add("❌ $url — request failed ($msg)")
    }
}

$canAlert = SlackCanWeNag -alertNum $SlackAlertNum -outofHours $OutOfHours

if ($breaches.Count -gt 0) {
    if ($canAlert) {
        $body = ($breaches -join "`n") + "`n`nBuilt by BOT-Solutions — https://bot-solutions.co.uk"
        [void](SlackSend -title "$SlackTitle (Alert #$SlackAlertNum)" -text $body -iconEmoji ":hourglass_flowing_sand:")
    }
    exit 1
}

exit 0