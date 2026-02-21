# PowerShell Slack Web Health Monitor

A lightweight PowerShell toolkit for monitoring website availability, response time, and SSL certificate expiry — with Slack alerts via an Incoming Webhook (no external modules required).

Built by BOT-Solutions — https://bot-solutions.co.uk

## What’s included

- **WebsiteStatusCheck.ps1**  
  Checks if endpoints are up and returning a healthy HTTP status.

- **HTTPResponseTime.ps1**  
  Measures response times and alerts when thresholds are breached.

- **SSLCertCheck.ps1**  
  Checks certificate expiry and alerts when within your warning window.

- **SLACKpost.psm1**  
  Minimal Slack webhook helper (uses `Invoke-RestMethod`).

## Quick start (5 minutes)

1) Clone / download this repo and open PowerShell in the folder.

2) Set your Slack Incoming Webhook URL (recommended via environment variable):

```powershell
setx SLACK_WEBHOOK_URL "https://hooks.slack.com/services/XXX/YYY/ZZZ"
