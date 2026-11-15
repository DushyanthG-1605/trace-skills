# Fire-and-forget event sender for Trace. Always exits 0.
# Usage: send-event.ps1 -Type agent.heartbeat [-Task TRC-21] [-Summary "..."] [-Reason "..."]
#        [-Confidence 0.9] [-Engineer name] [-Repo org/name] [-ExternalId id]
param(
  [Parameter(Mandatory = $true)][string]$Type,
  [string]$Task, [string]$Summary, [string]$Reason,
  [double]$Confidence = -1, [string]$Engineer, [string]$Repo, [string]$ExternalId
)
$ErrorActionPreference = "SilentlyContinue"
try {
  if (Test-Path "$HOME\.trace\disabled") { exit 0 }

  $key = $env:TRACE_API_KEY
  if (-not $key -and (Test-Path "$HOME\.trace\key")) { $key = (Get-Content "$HOME\.trace\key" -Raw).Trim() }
  if (-not $key) { exit 0 }

  $url = $env:TRACE_URL
  if (-not $url -and (Test-Path "$HOME\.trace\url")) { $url = (Get-Content "$HOME\.trace\url" -Raw).Trim() }
  if (-not $url) { $url = "http://localhost:3000" }

  if (-not $Repo) {
    $remote = git remote get-url origin 2>$null
    if ($remote -match '([^/:]+/[^/]+?)(\.git)?$') { $Repo = $Matches[1] }
  }
  if (-not $Engineer) { $Engineer = git config user.name 2>$null }

  $body = @{ type = $Type }
  if ($Task) { $body.task = $Task }
  if ($Summary) { $body.summary = $Summary.Substring(0, [Math]::Min(280, $Summary.Length)) }
  if ($Reason) { $body.reason = $Reason.Substring(0, [Math]::Min(2000, $Reason.Length)) }
  if ($Engineer) { $body.engineer = $Engineer }
  if ($Repo) { $body.repo = $Repo }
  if ($ExternalId) { $body.externalId = $ExternalId }
  if ($Confidence -ge 0 -and $Confidence -le 1) { $body.confidence = $Confidence }

  Invoke-RestMethod -Method Post -Uri "$url/api/events" -TimeoutSec 5 `
    -Headers @{ Authorization = "Bearer $key" } `
    -ContentType "application/json" `
    -Body ($body | ConvertTo-Json -Compress) | Out-Null
} catch { }
exit 0
