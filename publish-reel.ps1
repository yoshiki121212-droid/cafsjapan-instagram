<#
.SYNOPSIS
  Instagramリール（動画）投稿をローカルPCから直接公開するスクリプト。

.DESCRIPTION
  指定フォルダ内の動画(video.mp4)とcaption.txtをGitHubにpushしたうえで、
  Instagram Graph API (graph.instagram.com) を使ってリールとして公開する。
  publish-instagram.ps1（カルーセル用）と同じ長期トークン（.ig-token.json）を
  使い回す。動画は処理（トランスコード）に時間がかかるため、公開前に
  status_codeがFINISHEDになるまでポーリングする点がカルーセルと異なる。

.PARAMETER Folder
  投稿する動画(video.mp4)とcaption.txtが入っているフォルダ名
  （例: 261004-reel-denkigas）。このスクリプトと同じ階層にあること。

.PARAMETER ShareToFeed
  trueならフィードにも表示される（デフォルトtrue）。リールタブのみに
  出したい場合は -ShareToFeed:$false を指定。

.EXAMPLE
  .\publish-reel.ps1 -Folder 261004-reel-denkigas
#>
param(
    [Parameter(Mandatory = $true)][string]$Folder,
    [bool]$ShareToFeed = $true
)

$ErrorActionPreference = "Stop"
$IgUserId = "28982078078050899"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

if (-not (Test-Path $Folder)) {
    Write-Error "フォルダが見つかりません: $Folder"
    exit 1
}

$videoPath = Join-Path $Folder "video.mp4"
if (-not (Test-Path $videoPath)) {
    Write-Error "動画ファイルが見つかりません: $videoPath（video.mp4という名前で置いてください）"
    exit 1
}

Write-Host "=== 1. GitHubにpush ===" -ForegroundColor Cyan
git add $Folder
$hasChanges = (git status --porcelain $Folder)
if ($hasChanges) {
    git commit -m "Publish reel for $Folder"
} else {
    Write-Host "(変更なし、コミットをスキップ)"
}
git push origin main

$sha = (git rev-parse HEAD).Trim()
$remoteUrl = (git config --get remote.origin.url)
if ($remoteUrl -notmatch "github\.com[:/](.+?)(\.git)?$") {
    Write-Error "リモートURLからリポジトリ名を取得できませんでした: $remoteUrl"
    exit 1
}
$repoSlug = $matches[1]
Write-Host "リポジトリ: $repoSlug / コミット: $sha"

Write-Host "`n=== 2. Instagramアクセストークン ===" -ForegroundColor Cyan
$tokenFile = Join-Path $repoRoot ".ig-token.json"
if (-not (Test-Path $tokenFile)) {
    Write-Error "長期トークンのファイルが見つかりません ($tokenFile)。先に .\setup-ig-token.ps1 を実行してください。"
    exit 1
}

$tokenData = Get-Content $tokenFile -Raw -Encoding UTF8 | ConvertFrom-Json
$accessToken = $tokenData.access_token
$expiresAt = [datetime]::Parse($tokenData.expires_at).ToUniversalTime()
$daysLeft = ($expiresAt - (Get-Date).ToUniversalTime()).TotalDays
Write-Host "  現在のトークン有効期限: $($expiresAt.ToString('yyyy-MM-dd HH:mm')) UTC（残り約$([math]::Round($daysLeft, 1))日）"

if ($daysLeft -lt 10) {
    Write-Host "  期限が近いため、自動延長します..."
    $encodedCurrent = [uri]::EscapeDataString($accessToken)
    $refreshUrl = "https://graph.instagram.com/refresh_access_token?grant_type=ig_refresh_token&access_token=$encodedCurrent"
    try {
        $refreshed = Invoke-RestMethod -Method Get -Uri $refreshUrl
        $accessToken = $refreshed.access_token
        $newExpiresAt = (Get-Date).ToUniversalTime().AddSeconds($refreshed.expires_in)
        $newTokenData = @{
            access_token = $accessToken
            expires_at   = $newExpiresAt.ToString("o")
        } | ConvertTo-Json
        Set-Content -Path $tokenFile -Value $newTokenData -Encoding UTF8
        Write-Host "  延長完了。新しい有効期限: $($newExpiresAt.ToString('yyyy-MM-dd HH:mm')) UTC" -ForegroundColor Green
    } catch {
        Write-Error "トークンの自動延長に失敗しました。長期トークン自体が失効している可能性があります。.\setup-ig-token.ps1 を再実行してください。`n$($_.Exception.Message)"
        exit 1
    }
}
$encodedToken = [uri]::EscapeDataString($accessToken)

$captionPath = Join-Path $Folder "caption.txt"
$caption = ""
if (Test-Path $captionPath) {
    $caption = Get-Content $captionPath -Raw -Encoding UTF8
} else {
    Write-Warning "caption.txt が見つかりません。キャプションなしで投稿します。"
}
$encodedCaption = [uri]::EscapeDataString($caption)

Write-Host "`n=== 3. リールコンテナを作成 ===" -ForegroundColor Cyan
$encodedFolder = [uri]::EscapeDataString($Folder)
$videoUrl = "https://raw.githubusercontent.com/$repoSlug/$sha/$encodedFolder/video.mp4"
$encodedVideoUrl = [uri]::EscapeDataString($videoUrl)
$shareToFeedStr = if ($ShareToFeed) { "true" } else { "false" }
$createUrl = "https://graph.instagram.com/v21.0/$IgUserId/media?media_type=REELS&video_url=$encodedVideoUrl&caption=$encodedCaption&share_to_feed=$shareToFeedStr&access_token=$encodedToken"
$created = Invoke-RestMethod -Method Post -Uri $createUrl
$creationId = $created.id
Write-Host "  コンテナID: $creationId"

Write-Host "`n=== 4. 動画処理の完了を待機 ===" -ForegroundColor Cyan
$statusUrl = "https://graph.instagram.com/v21.0/$($creationId)?fields=status_code&access_token=$encodedToken"
$maxAttempts = 30
$ready = $false
for ($i = 1; $i -le $maxAttempts; $i++) {
    $status = Invoke-RestMethod -Method Get -Uri $statusUrl
    Write-Host "  状態: $($status.status_code) ($i/$maxAttempts)"
    if ($status.status_code -eq "FINISHED") {
        $ready = $true
        break
    }
    if ($status.status_code -eq "ERROR" -or $status.status_code -eq "EXPIRED") {
        Write-Error "動画の処理に失敗しました（status_code: $($status.status_code)）。動画の形式・長さを確認してください。"
        exit 1
    }
    Start-Sleep -Seconds 10
}
if (-not $ready) {
    Write-Error "動画処理がタイムアウトしました。しばらく待ってから、同じ creation_id ($creationId) で手動公開を試すか、再実行してください。"
    exit 1
}

Write-Host "`n=== 5. 公開 ===" -ForegroundColor Cyan
$publishUrl = "https://graph.instagram.com/v21.0/$IgUserId/media_publish?creation_id=$creationId&access_token=$encodedToken"
$maxPublishAttempts = 5
$published = $null
for ($i = 1; $i -le $maxPublishAttempts; $i++) {
    try {
        $published = Invoke-RestMethod -Method Post -Uri $publishUrl
        break
    } catch {
        if ($i -eq $maxPublishAttempts) { throw }
        Write-Host "  まだ処理中のようです。5秒待って再試行します... ($i/$maxPublishAttempts)"
        Start-Sleep -Seconds 5
    }
}
Write-Host "投稿完了！ Media ID: $($published.id)" -ForegroundColor Green
