# SSLCertCheck.ps1
# SSL certificate expiry monitoring with Slack alerts (no external dependencies)
# Built by BOT-Solutions — https://bot-solutions.co.uk

[CmdletBinding()]
param(
    # Accept hostnames or URLs (https://example.com)
    [Parameter(Mandatory = $false)]
    [string[]]$SitesToTest = @(
        "example.com",
        "https://example.org"
    ),

    [Parameter(Mandatory = $false)]
    [int]$WarningThresholdDays = 31,

    [Parameter(Mandatory = $false)]
    [string]$SlackTitle = "Web Health: SSL Expiry",

    [Parameter(Mandatory = $false)]
    [int]$SlackAlertNum = 17,

    [Parameter(Mandatory = $false)]
    [bool]$OutOfHours = $true,

    [Parameter(Mandatory = $false)]
    [int]$Port = 443,

    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module "$PSScriptRoot\SLACKpost.psm1" -Force

function Get-HostFromInput {
    param([Parameter(Mandatory=$true)][string]$InputValue)

    $value = $InputValue.Trim()

    if ($value -match '^\w+://') {
        try { return ([Uri]$value).Host } catch { return $value }
    }

    # Handle accidental path inputs like example.com/health
    if ($value -match '^([^/]+)') { return $Matches[1] }

    return $value
}

$alerts = New-Object System.Collections.Generic.List[string]

foreach ($site in $SitesToTest) {
    if ([string]::IsNullOrWhiteSpace($site)) { continue }

    $host = Get-HostFromInput -InputValue $site

    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $iar = $client.BeginConnect($host, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds))) {
            throw "Timeout connecting to $host:$Port"
        }
        $client.EndConnect($iar) | Out-Null

        $sslStream = [System.Net.Security.SslStream]::new($client.GetStream(), $false, ({ $true }))
        $sslStream.AuthenticateAsClient($host)

        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $sslStream.RemoteCertificate
        $expires = $cert.NotAfter
        $daysLeft = [int]([Math]::Floor(($expires - (Get-Date)).TotalDays))

        $sslStream.Dispose()
        $client.Dispose()

        if ($daysLeft -le $WarningThresholdDays) {
            $alerts.Add("⚠️ $host — expires $($expires.ToString('yyyy-MM-dd')) ($daysLeft days left)")
        }
    }
    catch {
        $alerts.Add("❌ $host — SSL check failed ($($_.Exception.Message))")
        try { if ($sslStream) { $sslStream.Dispose() } } catch {}
        try { if ($client) { $client.Dispose() } } catch {}
    }
}

$canAlert = SlackCanWeNag -alertNum $SlackAlertNum -outofHours $OutOfHours

if ($alerts.Count -gt 0) {
    if ($canAlert) {
        $body = ($alerts -join "`n") + "`n`nBuilt by BOT-Solutions — https://bot-solutions.co.uk"
        [void](SlackSend -title "$SlackTitle (Alert #$SlackAlertNum)" -text $body -iconEmoji ":lock:")
    }
    exit 1
}

exit 0