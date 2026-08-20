<#
.SYNOPSIS
  Instagramカルーセル投稿をローカルPCから直接公開するスクリプト。

.DESCRIPTION
  指定フォルダ内の画像(PNG/JPG)とcaption.txtをGitHubにpushしたうえで、
  Instagram Graph API (graph.instagram.com) を使ってカルーセル投稿として公開する。
  GitHub Actions(クラウドサーバー)からのPOSTリクエストはMeta側で
  拒否されることが確認されたため、自宅PCから直接実行する形にしている。

.PARAMETER Folder
  投稿する画像が入っているフォルダ名（例: 260819）。このスクリプトと同じ階層にあること。

.EXAMPLE
  .\publish-instagram.ps1 -Folder 260819
#>
param(
    [Parameter(Mandatory = $true)][string]$Folder
)

$ErrorActionPreference = "Stop"
$IgUserId = "28982078078050899"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

if (-not (Test-Path $Folder)) {
    Write-Error "フォルダが見つかりません: $Folder"
    exit 1
}

Write-Host "=== 1. GitHubにpush ===" -ForegroundColor Cyan
git add $Folder
$hasChanges = (git status --porcelain $Folder)
if ($hasChanges) {
    git commit -m "Publish images for $Folder"
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
Write-Host "developers.facebook.com の「トークンを生成」で発行した、なるべく新しいトークンを貼り付けてください。"
$accessToken = Read-Host "アクセストークン"
if ([string]::IsNullOrWhiteSpace($accessToken)) {
    Write-Error "アクセストークンが入力されませんでした。"
    exit 1
}
$encodedToken = [uri]::EscapeDataString($accessToken)

$imageFiles = Get-ChildItem -Path $Folder -File | Where-Object { $_.Extension -match '\.(png|jpg|jpeg)$' } | Sort-Object Name
if ($imageFiles.Count -eq 0) {
    Write-Error "画像ファイルが見つかりません: $Folder"
    exit 1
}
if ($imageFiles.Count -gt 10) {
    Write-Warning "カルーセルは最大10枚までです。先頭10枚だけ使用します。"
    $imageFiles = $imageFiles[0..9]
}

$captionPath = Join-Path $Folder "caption.txt"
$caption = ""
if (Test-Path $captionPath) {
    $caption = Get-Content $captionPath -Raw -Encoding UTF8
} else {
    Write-Warning "caption.txt が見つかりません。キャプションなしで投稿します。"
}
$encodedCaption = [uri]::EscapeDataString($caption)

Write-Host "`n=== 3. 画像コンテナを作成 ===" -ForegroundColor Cyan
$childIds = @()
foreach ($file in $imageFiles) {
    $encodedFolder = [uri]::EscapeDataString($Folder)
    $encodedFile = [uri]::EscapeDataString($file.Name)
    $imageUrl = "https://raw.githubusercontent.com/$repoSlug/$sha/$encodedFolder/$encodedFile"
    $encodedImageUrl = [uri]::EscapeDataString($imageUrl)
    $url = "https://graph.instagram.com/v21.0/$IgUserId/media?image_url=$encodedImageUrl&is_carousel_item=true&access_token=$encodedToken"
    $resp = Invoke-RestMethod -Method Post -Uri $url
    Write-Host "  $($file.Name) -> $($resp.id)"
    $childIds += $resp.id
}

Write-Host "`n=== 4. カルーセルコンテナを作成 ===" -ForegroundColor Cyan
$encodedChildren = [uri]::EscapeDataString(($childIds -join ","))
$carouselUrl = "https://graph.instagram.com/v21.0/$IgUserId/media?media_type=CAROUSEL&children=$encodedChildren&caption=$encodedCaption&access_token=$encodedToken"
$carousel = Invoke-RestMethod -Method Post -Uri $carouselUrl
$creationId = $carousel.id
Write-Host "  コンテナID: $creationId"

Write-Host "`n=== 5. 公開 ===" -ForegroundColor Cyan
Write-Host "(画像のみのカルーセルは処理がほぼ一瞬で終わるため、状態確認は省略して直接公開します)"
$publishUrl = "https://graph.instagram.com/v21.0/$IgUserId/media_publish?creation_id=$creationId&access_token=$encodedToken"
$published = Invoke-RestMethod -Method Post -Uri $publishUrl
Write-Host "投稿完了！ Media ID: $($published.id)" -ForegroundColor Green
