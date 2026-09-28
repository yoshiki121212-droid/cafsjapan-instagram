<#
.SYNOPSIS
  Instagram長期アクセストークンを初回セットアップ（または手動での作り直し）するスクリプト。

.DESCRIPTION
  developers.facebook.comで発行した短期トークンを、Instagram Graph APIの
  ig_exchange_token エンドポイントで60日間有効な長期トークンに交換し、
  .ig-token.json に保存する。以降、publish-instagram.ps1 はこのファイルを
  読み込み、期限が近ければ自動でrefreshするため、毎回トークンを貼り付ける
  必要がなくなる。

  このスクリプトを実行するのは以下のタイミングだけでよい：
  ・初回セットアップ時
  ・.ig-token.json を紛失/破損した場合
  ・60日の自動refreshが何らかの理由で途切れ、長期トークン自体が失効した場合

.PARAMETER AccessToken
  developers.facebook.comの「トークンを生成」で発行した短期トークン。

.PARAMETER AppSecret
  Meta for Developersの、このInstagramアプリの「Instagram業種」設定に
  表示されるapp secret（アプリの設定→基本設定に出てくる旧来のFacebookアプリ
  シークレットとは別物なので注意）。

.EXAMPLE
  .\setup-ig-token.ps1
  (対話式でトークンとapp secretの入力を求められる)
#>
param(
    [string]$AccessToken,
    [string]$AppSecret
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot
$tokenFile = Join-Path $repoRoot ".ig-token.json"

if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    Write-Host "developers.facebook.com の「トークンを生成」で発行した、短期アクセストークンを貼り付けてください。"
    $AccessToken = Read-Host "短期アクセストークン"
}
if ([string]::IsNullOrWhiteSpace($AppSecret)) {
    Write-Host "Instagramアプリのapp secret（Instagram業種の設定画面にあるもの）を貼り付けてください。"
    $secureSecret = Read-Host "app secret" -AsSecureString
    $AppSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)
    )
}
if ([string]::IsNullOrWhiteSpace($AccessToken) -or [string]::IsNullOrWhiteSpace($AppSecret)) {
    Write-Error "アクセストークンまたはapp secretが入力されませんでした。"
    exit 1
}

Write-Host "`n=== 短期トークンを長期トークンに交換 ===" -ForegroundColor Cyan
$encodedToken = [uri]::EscapeDataString($AccessToken)
$encodedSecret = [uri]::EscapeDataString($AppSecret)
$exchangeUrl = "https://graph.instagram.com/access_token?grant_type=ig_exchange_token&client_secret=$encodedSecret&access_token=$encodedToken"

$result = Invoke-RestMethod -Method Get -Uri $exchangeUrl
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
