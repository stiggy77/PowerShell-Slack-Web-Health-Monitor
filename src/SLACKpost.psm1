# SLACKpost.psm1
# Lightweight Slack webhook helper (no external dependencies)
# Built by BOT-Solutions — https://bot-solutions.co.uk

# Set this to your Slack Incoming Webhook URL:
# https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
# Tip: You can also set an environment variable SLACK_WEBHOOK_URL and leave this blank.
$Script:SlackWebhookUrl = ""

# Simple quiet-hours controls
$Script:BusinessHoursStart = 08  # 08:00
$Script:BusinessHoursEnd   = 18  # 18:00 (end exclusive)

function SlackCanWeNag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$alertNum,
        [Parameter(Mandatory=$true)][bool]$outofHours
    )

    if ($outofHours) { return $true }

    $now = Get-Date
    if ($now.DayOfWeek -in @('Saturday','Sunday')) { return $false }

    return ($now.Hour -ge $Script:BusinessHoursStart -and $now.Hour -lt $Script:BusinessHoursEnd)
}

function SlackSend {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$title,
        [Parameter(Mandatory=$true)][string]$text,
        [Parameter(Mandatory=$false)][string]$iconEmoji = ":warning:"
    )

    $webhook = $env:SLACK_WEBHOOK_URL
    if ([string]::IsNullOrWhiteSpace($webhook)) { $webhook = $Script:SlackWebhookUrl }

    if ([string]::IsNullOrWhiteSpace($webhook)) {
        throw "Slack webhook URL not set. Set `$Script:SlackWebhookUrl in SLACKpost.psm1 or set env var SLACK_WEBHOOK_URL."
    }

    $payload = @{
        text       = "*$title*`n$text"
        icon_emoji = $iconEmoji
    } | ConvertTo-Json -Depth 6

    try {
        Invoke-RestMethod -Method Post -Uri $webhook -Body $payload -ContentType 'application/json' | Out-Null
        return $true
    }
    catch {
        Write-Warning ("SlackSend failed: " + $_.Exception.Message)
        return $false
    }
}

Export-ModuleMember -Function SlackCanWeNag, SlackSend