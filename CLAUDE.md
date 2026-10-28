# プロジェクト概要

政治団体「財政健全化を求める市民の会」代表・桑原由樹の、Instagram投稿（現在はリール動画が主軸）を作成する作業スペースです。

- 団体名: 財政健全化を求める市民の会 / 代表: 桑原由樹
- 公式サイト: https://www.cafsjapan.com/
- Instagramアカウント: https://www.instagram.com/cafs.japan/

`note/` `X/` フォルダも用意されています。note/の記事はInstagramのネタ元としても使います。

## チーム体制

- **分析課**（`reel-analyst`サブエージェント）：過去の投稿実績（到達・閲覧・離脱率・保存/シェア等）を分析し、企画課・作成課それぞれへの申し送り事項を出す。企画・制作は行わない。
- **企画課**（`reel-planner`サブエージェント）：分析課の申し送りを起点にネタ案を出す。制作は行わない。
- **校正課**（`reel-qa`サブエージェント）：完成したリールの品質チェックのみ行う（修正はしない）。
- **作成課**：この対話セッション自身（HyperFramesで制作し、ユーザーとやり取りする窓口）。

新しいリールは必ず **①分析課→②企画課（①の結果をプロンプトに含めて依頼）→③作成課（制作）** の順で進める。分析課の「作成課への申し送り事項」は企画課の出力に転記されるので、作成課は企画課の出力だけ見ればよい。

## 発信方針

- **リール（動画）優先。カルーセルは当面行わない。**
- **当面の目標：1本のリールで100閲覧（views）を達成する。** 非フォロワーへのリーチ（発見タブ経由）を狙って逆算でテーマ・フック・CTAを決める。
- 更新頻度：週3回（月・水・金）で試験運用中。
- ネタ元：基本は`note/`の記事を要約・再構成。無い場合は出典を明記した上で個別に事実確認する。
- 主なテーマ：財政・消費税・国債・社会保障・最低賃金などの経済ニュース解説。

## リール制作ワークフロー

**文章の分かりやすさ：30代OLが動画だけを見て理解できることを基準にする。** 専門用語・制度の背景知識を前提にせず、登場する数字や制度の意味（何がどう変わるか、なぜそう呼ばれるか等）を動画本編のテキストだけで説明しきる。キャプションを読まないと分からない内容を動画側に残さない。

1. **分析課→企画課の順で依頼する。** 分析課（`subagent_type: "reel-analyst"`）にInstagram/instagram-post-metrics-<日付>.csv（最新ファイル）を分析させ、その結果（特に「企画課への申し送り事項」）を企画課（`subagent_type: "reel-planner"`）への依頼プロンプトに含める。企画課は5案出し1〜2本を推薦し、分析課の「作成課への申し送り事項」を出力にそのまま転記する。
   - 推薦案の中から`Instagram/`内の既存フォルダ名と重複しないテーマを1つ選ぶ。出典が「未確認」の数字は制作前に裏取りする。
   - 新しいリールが一定期間投稿され数字が付いたら、Windsor.ai MCPで最新インサイトを取得し`instagram-post-metrics-<日付>.csv`に追記して鮮度を保つ。
2. **素材**：Pixabay API（キー: `57870836-72d9cfbb0179beca7f17cda7b`、`https://pixabay.com/api/`・`/videos/`）で、シーンの文言に直接結びつく実写素材を毎回新規に探す。**クラウドルーティンからも接続できる**（2026-10-28確認、環境Defaultの許可ドメインに`pixabay.com`・`*.pixabay.com`登録済み）。候補は必ず目視で確認し（文言との結びつき・外国通貨や外国語テキストの有無）、直近2本のリールと同じ写真は使わない（左右反転での使い回しも不可）。採用した画像は`Instagram/assets/stock/`にも保存してコミットし、出典としてPixabayのpageURLをmedia-manifest.txtに残す。Pixabayに接続できない日だけ`Instagram/assets/stock/`から選ぶ。
3. **制作**：HyperFrames（`npx hyperframes init <dir> --non-interactive --example=blank`）で1080×1350、ダークネイビー(`#0b1420`)×アンバー(`#d9a441`)のブランドCSS（mesh-gradient背景、kickerピル、headline/sub/hero-num見出し、footer、左上`top:96px`にCAFSロゴ）を使う。見出しはGoogle Fontsの「Zen Kaku Gothic New」Black(900)を使用文字のみサブセットで埋め込む。
4. **1シーン1情報、十分な読了時間**：1シーン1事実。文字表示から次シーンまで最低2〜3秒の余白を確保する。単調さを避けるため、シーンごとにアイコンの種類を変え、実写素材は最低2シーンに使いKen Burnsズーム（4秒で1.0→1.08〜1.1）を付け、数字・見出しの登場は`back.out(1.6)`のオーバーシュートを使い、kickerピルはスライドのみ（フェードは使わない）で登場させる。
5. **品質確認**：`npx hyperframes lint`→`check`でエラー0件・コントラストWCAG AA合格を確認し、`npx hyperframes render --quality looks --output final.mp4`でレンダリング。
6. **保存**：`Instagram/<YYMMDD>-reel-<スラッグ>/`に`video.mp4`と`caption.txt`を保存。
7. **公開前に必ずメールで確認を取る**：Gmail（`yoshiki121212@gmail.com`宛）で完成報告・確認依頼を送り、了承を得てから公開する。**絶対に即座にWindsor.ai経由で公開しない。** メールには、テーマ選定理由、分析課の分析結果（全体傾向・ハイライト・仮説・企画課への申し送り）、出典、reel-qaの結果概要を含める。
8. **公開**：了承後、GitHubへのpushはユーザー自身に依頼し、push後にWindsor.ai経由で`create_video_post`により公開する。

## Windsor.ai経由の投稿

- `execute_action`（connector: `instagram`, action: `create_video_post`）で、Claudeがチャット内から直接公開できる。
- 手順：①`video.mp4`・`caption.txt`を`Instagram/<フォルダ名>/`に用意→②GitHubにpush→③`raw.githubusercontent.com/<repo>/<commit sha>/<フォルダ>/video.mp4`が200を返すことを確認→④`get_connectors`でアカウントID（`17841452838964183`、instagram/cafs.japan）を取得→⑤`execute_action`に`video_url`・`caption`・`share_to_feed`（・`thumb_offset`でカバー指定）を渡す。
- **GitHubへのpushは対話セッションからはできない**（Git Credential Managerが対話的TTYを要求し失敗する）。必ずユーザー自身のPowerShellで`git push origin main`を実行してもらう。クラウドルーティンからのpushは問題なく成功する。
- フォールバック：`publish-reel.ps1`（ローカルPCでGraph API直叩き、長期トークン使用）。Windsor側が使えなくなった場合用に保持。

### BGM方針

- 対話セッションでの制作は **Incompetech（Kevin MacLeod、CC BY 4.0）** から曲調に合う曲を選ぶ（`incompetech.com/music/royalty-free/mp3-royaltyfree/<曲名>.mp3`で直接ダウンロード、APIキー不要）。キャプションに`Music: <曲名> by Kevin MacLeod (incompetech.com)\nLicensed under Creative Commons: By Attribution 4.0`のクレジットが必須。直近のリールと同じ曲を続けて使わない（reel-qaのチェック対象）。
- クラウドルーティンはIncompetechに接続できないため、`Instagram/assets/bgm/`の事前生成ライブラリ（`bgm-calm-01.wav`等）から選ぶ。キャプションのクレジットも「CAFS Instagram運用 自主制作BGM／MusicGen生成」表記にする。

### 素材ライブラリ（クラウドルーティン用）

クラウド実行環境（Default）の接続可否（2026-10-28確認）：`pixabay.com`・`huggingface.co`は**接続可**（許可ドメインに登録済み）、`incompetech.com`・`cdn.jsdelivr.net`は**接続不可**。接続できないものは以下の事前選定ライブラリから選ぶ。許可ドメインの設定場所：claude.ai/code →「＋新規作成」→ 入力欄下の「Default」→「クラウド ＞」→ Defaultの編集 →「ネットワークアクセス」。なおルーティン`trig_01KS5qiZj5gZmnFmZHtTkvbQ`はhttp_api経由で作成されたため、Claudeからは指示文を更新できない（ユーザーが`claude.ai/code/routines/trig_01KS5qiZj5gZmnFmZHtTkvbQ`で編集する）。
- `Instagram/assets/bgm/`：生成済みBGM（`bgm-calm-01.wav`＝穏やか、`bgm-upbeat-01.wav`＝明るい、他）。
- `Instagram/assets/stock/`：目視確認済みの実写素材（外国通貨・外国語テキスト・実在人物の顔が写っていないもの）。手薄になったら対話セッション側で追加してコミットする。
- gsapは`npm install gsap`してプロジェクト内`vendor/gsap.min.js`にコピーしローカル参照する（`cdn.jsdelivr.net`回避）。
- 素材が無い場合は実写なし・無音で進めてよい（処理を止めない）。ユーザーには何を省略したかをメールで明記する。

## Instagram API認証（長期トークン）

`publish-reel.ps1`フォールバック用。通常はWindsor.ai経由のため意識不要。

- `IG_USER_ID`は`28982078078050899`（Graph API側に見える`17841452838964183`とは別物）。
- `Instagram/.ig-token.json`（gitignore対象）に長期トークン（60日有効）を保存し、有効期限10日未満で自動的に`https://graph.instagram.com/refresh_access_token?grant_type=ig_refresh_token&access_token=<現トークン>`を呼んで延長する。
- developers.facebook.comで発行されるトークンは発行時点で**すでに長期トークン**（`ig_exchange_token`交換は不要、実行するとエラーになる）。上記refreshエンドポイントに直接通すだけでよい。
- トークン紛失・失効時は`Instagram/setup-ig-token.ps1`を実行し、対話入力欄（チャットではなく）にトークンを貼り付ける。

## クラウドルーティン（自動実行）

- 「月・水・金17時頃にメールが来る」のは、claude.aiの**RemoteTrigger**（`/schedule`で作成、トリガーID: `trig_01KS5qiZj5gZmnFmZHtTkvbQ`、名前"Instagram reel prep (Sun/Wed)"）。Anthropicクラウド上で独立実行され、対話セッションを閉じても無期限に動く。`RemoteTrigger`ツールの`get`/`update`/`run`で確認・変更・手動実行できる（`CronCreate`は使わない）。
- 対象リポジトリ`cafsjapan-instagram`へのpushはクラウドルーティンから問題なく成功する。
- cron: `0 8 * * 1,3,5`（UTC 8:00=日本時間17:00、月・水・金）。**変更した場合は必ずこの値に戻すこと**（二重発火防止のため一時的に変更したまま放置しない）。
- 内容は上記「リール制作ワークフロー」に準じる。**Windsor.aiのexecute_actionは絶対に呼ばず**、Gmailで完成報告・確認依頼を送り、ユーザーの「公開してください」の返信を待つ。mcp_connectionsにGmail・Windsor-ai・Claude_Code_Remoteを接続済み。
- 姉妹ルーティン「note下書き作成・Gmail配信」（`trig_01YLBKhm6gBd9dJbXgvZYoqi`、対象`cafsjapan-note`）はこのInstagram方針と無関係。
