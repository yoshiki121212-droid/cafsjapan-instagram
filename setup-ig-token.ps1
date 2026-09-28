<#
.SYNOPSIS
  Instagram長期アクセストークンを初回セットアップ（または手動での作り直し）するスクリプト。

.DESCRIPTION
  developers.facebook.comの「トークンを生成」で発行されるトークンは、
  実際には発行された時点ですでに60日間有効な長期トークンである
  （ig_exchange_tokenでの「交換」は不要、というより無効な操作でエラーになる
  ことを2026-09-30に確認済み）。このスクリプトはそのトークンをそのまま
  ig_refresh_token エンドポイントに通して有効期限を確定させ（60日にリセット
  される）、.ig-token.json に保存する。以降、publish-instagram.ps1 はこの
  ファイルを読み込み、期限が近ければ自動でrefreshするため、毎回トークンを
  貼り付ける必要がなくなる。app secretは一切不要。

  このスクリプトを実行するのは以下のタイミングだけでよい：
  ・初回セットアップ時
  ・.ig-token.json を紛失/破損した場合
  ・60日の自動refreshが何らかの理由で途切れ、長期トークン自体が失効した場合

.PARAMETER AccessToken
  developers.facebook.comの「トークンを生成」で発行したトークン。

.EXAMPLE
  .\setup-ig-token.ps1
  (対話式でトークンの入力を求められる)
#>
param(
    [string]$AccessToken
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot
$tokenFile = Join-Path $repoRoot ".ig-token.json"

if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    Write-Host "developers.facebook.com の「トークンを生成」で発行したトークンを貼り付けてください。"
    $AccessToken = Read-Host "アクセストークン"
}
$AccessToken = $AccessToken.Trim()
if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    Write-Error "アクセストークンが入力されませんでした。"
    exit 1
}

Write-Host "  受け取ったアクセストークン: 長さ$($AccessToken.Length)文字、先頭 '$($AccessToken.Substring(0, [Math]::Min(8, $AccessToken.Length)))...'"
if ($AccessToken.Length -lt 100) {
    Write-Warning "アクセストークンが短すぎます（通常は100文字を大きく超えます）。コピー時に途切れていないか確認してください。"
}
if ($AccessToken -match '\s') {
    Write-Warning "アクセストークンの中に空白または改行が含まれています。コピー範囲がずれている可能性があります。"
}

Write-Host "`n=== トークンの有効期限を確定（60日にリセット） ===" -ForegroundColor Cyan
$encodedToken = [uri]::EscapeDataString($AccessToken)
$refreshUrl = "https://graph.instagram.com/refresh_access_token?grant_type=ig_refresh_token&access_token=$encodedToken"

$result = Invoke-RestMethod -Method Get -Uri $refreshUrl
if (-not $result.access_token) {
    Write-Error "長期トークンの取得に失敗しました。レスポンス: $($result | ConvertTo-Json)"
    exit 1
}

$expiresAt = (Get-Date).ToUniversalTime().AddSeconds($result.expires_in)
$tokenData = @{
    access_token = $result.access_token
    expires_at   = $expiresAt.ToString("o")
} | ConvertTo-Json

Set-Content -Path $tokenFile -Value $tokenData -Encoding UTF8
Write-Host "長期トークンを保存しました: $tokenFile" -ForegroundColor Green
Write-Host "有効期限（UTC）: $($expiresAt.ToString('yyyy-MM-dd HH:mm'))（約60日間）"
Write-Host "`nこれで publish-instagram.ps1 はこのファイルを自動で読み込み、期限が近づくと自動延長します。"
