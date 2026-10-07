# プロジェクト概要

このプロジェクトは、政治団体「財政健全化を求める市民の会」代表・桑原由樹が、Instagram投稿（現在はリール動画が主軸）の原稿・動画・キャプション・ハッシュタグを作成するための作業スペースです。

- 団体名: 財政健全化を求める市民の会
- 代表: 桑原由樹
- 公式サイト: https://www.cafsjapan.com/
- Instagramアカウント: https://www.instagram.com/cafs.japan/（2026年8月時点フォロワー約12人、伸び悩み中）

`note/` `X/` フォルダも用意されています。note/では記事を作成しており、Instagramのネタ元としても活用します。

## 発信方針（2026-10-04、リール優先に方針転換）

- **リール（動画）を主軸に発信する。** カルーセルはしばらく行わない（カルーセル作成の仕組み・過去ルールは2026-10-05にこのファイルから削除した。再開する場合はgit履歴を参照）。
- **当面の数値目標（2026-10-05確定）：まず1本のリールで100閲覧（views）を達成することを目指す。** 現状、カルーセル・リールともにreach/viewsは1桁台にとどまっている（フォロワーがほぼ見ていない状態）。100閲覧という目標は、非フォロワーへのリーチ（発見タブ・おすすめ経由の再生）を本気で取りにいかないと達成できない水準のため、テーマ選定・フック・CTAのすべてをこの目標から逆算して決めること。
  - 「ガソリン税の暫定税率廃止」のリール（261006-reel-gasolin-zei）は練習用の試作として扱い、当面は公開しない。将来ネタとして使う可能性はあるため削除はしないが、次回以降のリールは別テーマで新規に作る。
- **更新頻度の目標：週2回**
- **ネタ元: note/の記事を要約し、Instagram向けに再構成する**のを基本とする。note記事が無いテーマを扱う場合は、出典を明記した上で個別に事実確認する。
- 主なテーマ: 経済ニュース解説（特に財政・消費税・国債・社会保障・最低賃金など、団体の政策領域）

## Instagram API 認証（長期トークン、共通基盤）

リール投稿は基本的にWindsor.ai経由（下記）で行うため通常は意識不要だが、ローカルPCでの直接投稿（`publish-reel.ps1`、フォールバック用）はこの仕組みに依存する。

- `IG_USER_ID`は`28982078078050899`（Facebook Graph API側で見えるID`17841452838964183`とは別物。`graph.instagram.com`用にはApp-Scoped User IDである前者を使う）。
- **長期トークン化（2026-09-30対応）**：`Instagram/.ig-token.json`（gitignore対象、コミットしない）に長期アクセストークン（60日間有効）と有効期限を保存しておき、各スクリプトが投稿の都度これを読み込む。有効期限まで10日を切っていたら、`https://graph.instagram.com/refresh_access_token?grant_type=ig_refresh_token&access_token=<現在の長期トークン>`を自動で呼び出してさらに60日延長し、ファイルを上書きする。
  - **重要な発見**：developers.facebook.comの「トークンを生成」ボタンで発行されるトークンは、発行された時点で**すでに60日間有効な長期トークン**になっている。「短期トークン→長期トークン」への`ig_exchange_token`交換は不要で、実行すると`Session key invalid`（code 452）という紛らわしいエラーになる。正しくは、発行されたトークンをそのまま`ig_refresh_token`（＝上記の延長エンドポイント）に通すだけでよい。app secretは一切不要。
  - 初回セットアップ、または`.ig-token.json`を紛失・長期トークン自体が失効した場合のみ、`Instagram/setup-ig-token.ps1`を実行する。developers.facebook.comで発行したトークンを対話式で入力すると、上記のrefreshを1回実行して有効期限を確定させ、`.ig-token.json`に保存する。トークンは**チャットではなくPowerShellの対話入力欄に直接貼り付ける**運用にしている（会話ログに秘密情報を残さないため）。
- Instagramアカウント連携のセットアップ（ビジネスアカウント化→Facebookページ/ビジネスポートフォリオ連携→Meta for Developersでアプリ作成→Instagramユースケース追加→Instagramテスターとしてユーザーネームを登録→承認→アクセストークン発行）はMeta側の作業のためユーザー本人が行う必要がある。特に「Instagramテスター」の役割は、Facebookアカウント名ではなくInstagramのユーザーネームで登録する点がハマりやすい。

## リール（動画）投稿：Windsor.ai経由（2026-10-04確認、実際に使う方式）

- **リール（動画）はWindsor.ai MCPコネクタの`execute_action`（connector: `instagram`, action: `create_video_post`）で、Claudeがチャット内から直接公開できる。** Meta側のクラウドIPブロックはWindsor側のサーバーが代行して呼び出すため影響を受けない。
  - 手順：①動画・caption.txtを`Instagram/<フォルダ名>/`（`video.mp4`固定名）に用意→②GitHubにpush→③`raw.githubusercontent.com/<repo>/<commit sha>/<フォルダ>/video.mp4`のURLを組み立て（200が返ることをcurlで確認）→④`get_connectors`でアカウントID（`17841452838964183`、instagram/cafs.japan）を取得→⑤`execute_action`に`video_url`・`caption`・`share_to_feed`を渡す。トランスコード完了待ちのポーリングはWindsor側が内部で処理するため、手動ポーリングは不要。
  - **ただしGitHubへのpushはClaude Code自身の対話セッションの実行環境からはできない。** Git Credential Manager (`credential.helper=manager`)が対話的ターミナル（GUIプロンプトやTTY）を要求するため、Bash/PowerShellツールから`git push`すると`terminal prompts disabled`で失敗する。pushは必ずユーザー自身が自分のPowerShellウィンドウで`cd`して`git push origin main`を実行する必要がある（`git fetch`など読み取り専用操作はpublicリポジトリなら認証不要で通る）。**クラウドルーティン（下記`RemoteTrigger`経由）からのpushは問題なく成功する**ので、この制約は対話セッション固有のもの。
  - `publish-reel.ps1`（ローカルPCで動かすGraph API直叩き版、status_codeポーリング込み、上記の長期トークンを使用）も作成済みで、Windsor側のアクションが将来使えなくなった場合のフォールバックとして残している。
  - **BGM：MusicGen（ローカル生成、2026-10-05に方式確定）。** 無音のリールは一般的でないというユーザー指摘を受け、音楽を焼き込む方針にした。HeyGenの音源カタログ（ブラウザ/デバイス認証が必要で対話セッション・クラウドルーティンどちらでも「unattended」判定され使えない）や、GoogleのLyria（`GEMINI_API_KEY`が必要、今回ユーザーから渡されたキーが標準形式`AIzaSy...`と異なり検証もセキュリティ分類器にブロックされたため見送り）は不採用。代わりに**Meta製MusicGen（`facebook/musicgen-small`）をローカルでPython実行し、APIキー不要・完全ローカルで生成**する方式を採用した。
    - 依存関係：`pip install transformers torch soundfile numpy`（初回は約1〜2GB、モデル本体は`facebook/musicgen-small`からHugging Face経由で自動ダウンロードされキャッシュされる）。
    - 生成方法：`AutoProcessor`/`MusicgenForConditionalGeneration`で`facebook/musicgen-small`をロードし、`model.generate(**inputs, max_new_tokens=int(秒数*50))`で生成（1秒あたり約50トークン、1回の生成で安全に作れるのは30秒弱までがデコーダの実用上限）。生成したら0.8秒程度のフェードイン・フェードアウトをかけ、ピーク正規化（0.9程度）して`.wav`で書き出す。
    - 動画への組み込み：HyperFramesの`index.html`で、ルート直下に`<audio id="bgm" src="media/bgm.wav" data-start="0" data-track-index="20" data-volume="0.55"></audio>`を追加するだけでよい（`<video>`と違い`class="clip"`は付けない。音量0.55はナレーションが無い＝BGMのみの動画としての目安値、必要に応じて調整）。
    - 所要時間の目安：このPC（CPU）ではモデル読み込みが初回約2分・2回目以降（ローカルキャッシュ利用時）は数十秒、生成は29秒のBGMで約170秒。生成に失敗した場合は音楽なしにフォールバックしてよい（処理を止めない）。
  - **【重要・2026-10-07判明】クラウドルーティンはpixabay.com・huggingface.comに接続できず、BGM・実写素材とも毎回失敗していた。** 2026-10-07(水)の自動実行（261007-reel-shohizei-zaigen）で、クラウド実行環境のネットワークポリシーが`pixabay.com`・`huggingface.co`への接続をブロックすることが判明し、BGM（MusicGen、モデルダウンロードがHugging Face経由）も実写素材（Pixabay API）も一切追加されないまま完成していた。ローカルPC（対話セッション）側は別のネットワークポリシーのため問題なく動く。
  - **恒久対策：`Instagram/assets/`配下に事前生成・事前選定した素材ライブラリをコミットし、クラウドルーティンはネットワーク越しの取得をせずこのライブラリから選ぶ方式にした（2026-10-07対応）。**
    - `Instagram/assets/bgm/`：MusicGenでローカル生成し検証済みのBGM（`.wav`、29秒前後）を複数種類ストック。現在`bgm-calm-01.wav`（穏やか・解説向け、92bpm）と`bgm-upbeat-01.wav`（明るい・前向きな内容向け、112bpm）の2種類。新しいリールのトーンに合わせてどちらかを選び、`media/bgm.wav`としてプロジェクトにコピーして使う。ライブラリが手薄になってきたら、ローカル（対話セッション）側でMusicGenを使い追加生成してコミットする。
    - `Instagram/assets/stock/`：Pixabayで事前に目視確認済みの、どの国でも通用する（または日本と確実に分かる）実写素材。現在`coins-stack-01.jpg`（硬貨のクローズアップ）、`calculator-finance-01.jpg`（計算機のクローズアップ）の2点。テーマに合わせて選ぶ。新しいテーマで合う素材がライブラリに無い場合は、ローカル側でPixabayから探して目視確認のうえ追加する（国籍チェックのルールは変わらず適用する）。
    - クラウドルーティンのプロンプトはこのライブラリから選ぶよう更新済み（Pixabay API・MusicGen生成そのものはクラウドからは試みない）。

## リール動画ワークフロー

新しいリールを作るたびに、以下の順序を徹底する。

1. **ネタ出しは`reel-planner`サブエージェントに任せる（2026-10-05導入）**：新しいリールの構成を考える前に、必ず`reel-planner`サブエージェント（`.claude/agents/reel-planner.md`、Agentツールで`subagent_type: "reel-planner"`として呼び出す）にネタ出しを依頼する。このエージェントは制作を行わず、`Instagram/instagram-post-metrics-<日付>.csv`（投稿実績）と団体の立場（2つの安心運動）を踏まえて、型タグ・冒頭3秒の一文・骨子・出典・キャプション案つきの案を5つ出し、1〜2本を推薦する。**制作側（このワークフローの続き）は、推薦案の中から、`Instagram/`内の既存ファイル・フォルダ名と重複しないテーマを1つ選んで採用する。** reel-plannerの提案を鵜呑みにせず、出典が「未確認」とされている数字は制作前に裏取りする。
   - **実績CSVの鮮度維持**：reel-plannerはCSVスナップショットを読むだけで、Windsor.aiへのライブアクセス権限を持たない（意図的にRead/Glob/WebSearch/WebFetchのみ）。新しいリールが一定期間投稿され数字が付いたら、Windsor.ai MCPで最新のインサイト（リーチ・閲覧・保存・シェア・冒頭3秒離脱率・平均視聴秒）を取得し、このCSVに行を追記して鮮度を保つこと（頻度の決まりはまだないが、放置するとreel-plannerの判断材料が古くなる）。
   - 2026-10-05時点の一般的なReelsベストプラクティス（最初の3秒で結論を見せる／文脈説明から入らない／本物の映像を使う方が伸びる）もあわせて意識する。**上記「当面の数値目標」の100閲覧を基準に、最終的なフック・CTAを決める**（非フォロワーへのリーチを増やす工夫を優先し、単なる作風の微調整にとどめない）。
2. **素材**：対話セッションではPixabayの画像・動画API（キー: `57870836-72d9cfbb0179beca7f17cda7b`、エンドポイント `https://pixabay.com/api/` と `https://pixabay.com/api/videos/`）で、テーマに合う実写の写真・短い動画を1〜2点組み込む。**クラウドルーティンではPixabay APIに接続できないため、`Instagram/assets/stock/`の事前選定ライブラリから選ぶ**（詳細は下記「BGM：MusicGen」節の直後にある恒久対策の項を参照）。
3. **制作**：HyperFrames（`npx skills add heygen-com/hyperframes`で未導入なら追加、`npx hyperframes init <dir> --non-interactive --example=blank`）で作成する。1080×1350、ダークネイビー(`#0b1420`)×アンバー(`#d9a441`)のブランドCSS（mesh-gradient背景、kickerピル、headline/sub/hero-num見出し、footer、左上`top:96px`にCAFSロゴ透過PNG）を使う。ロゴは白背景バッジで囲んだり回転させたりせず、透過のまま等倍角度でそのまま置く。見出し等にはGoogle Fontsの「Zen Kaku Gothic New」Black(900)を使用文字だけのサブセットで埋め込むと訴求力が上がる（本文はシステムフォントでよい）。
4. **1シーン1情報・十分な読了時間を徹底する（2026-10-05、重要な訂正）
   - 1シーンには事実・メッセージを1つだけ入れる（2つ以上の事実がある場合はシーンを分ける）。
   - 文字が出てから次のシーンに切り替わるまで、最低でも2〜3秒の「読み切れる余白」をタイムラインに確保する。
   - **視覚的な単調さを避ける（2026-10-07、ユーザーからの率直なフィードバックで追加）**：自動生成された261007-reel-shohizei-zaigenの初稿は、全7シーンが「同じ配色・同じkickerピル・同じ位置の1個のSVGアイコン・同じフェードイン」で構成されており、ユーザー自身が「見ていてつまらない、指を止めづらい」と評した。以後、次を徹底する。
     - シーンごとに使うアイコンの種類を変える（同じ輪郭・同じ配置の繰り返しにしない）。
     - 実写素材（`Instagram/assets/stock/`）を最低2シーンには使い、素材ごとに緩やかなKen Burnsズーム（`scale`を4秒程度かけて1.0→1.08〜1.1に変化させるなど）を付けて静止画でも動きを感じさせる。
     - 数字・見出しの登場は単純なフェードだけでなく、`back.out(1.6)`のような軽いオーバーシュート（弾むような飛び出し）を使うと、テンポよく見える。
     - kickerピルはフェードではなくスライドのみで登場させる（フェード中に半透明化し、コントラストチェックで引っかかることがあるため）。
   - テキストが少なく画面の半分近くが余る構成は避ける。関連する画像や動画などを空いた側に配置して埋める。
5. **品質確認**：`npx hyperframes lint`→`npx hyperframes check`を実行し、エラー0件・コントラストWCAG AA合格を確認してから`npx hyperframes render --quality looks --output final.mp4`でレンダリングする。
6. **保存**：`Instagram/<YYMMDD>-reel-<スラッグ>/`（YYMMDDは投稿予定日）フォルダに`video.mp4`と`caption.txt`（キャプション案＋ハッシュタグ案）を保存する。
7. **公開前にメールで確認を取る（2026-10-05、重要な訂正）**：動画ファイルが完成したら、**即座にWindsor.ai経由で公開してはいけない**。まずGmail（`yoshiki121212@gmail.com`宛）でユーザーに完成報告・確認依頼を送り、ユーザーの了承を得てから初めて公開する。
8. **公開**：ユーザーの了承後、GitHubへのpushはユーザー自身にお願いし（上記の制約のため）、push後にWindsor.ai経由で`create_video_post`により公開する。

## 自動ルーティンの正体と設定（2026-10-05、判明・更新済み）

- 「日・水17時頃にCAFS事務局名義でメールが来る自動準備」は、セッション内だけの`CronCreate`ではなく、**claude.aiのRemoteTrigger（クラウドルーティン、`/schedule`で作る仕組み）**で作られている。Anthropicのクラウド上で独立したセッション（CCR）として動き、対話セッションを閉じても**無期限に動き続ける**（`CronCreate`のような7日失効もセッション依存もない）。`RemoteTrigger`ツールの`list`で一覧取得・`get`で詳細確認・`update`で内容変更ができる。
- 該当ルーティンのID: `trig_01KS5qiZj5gZmnFmZHtTkvbQ`（名前"Instagram reel prep (Sun/Wed)"）。対象リポジトリは`cafsjapan-instagram`（**このルーティンはpushが問題なく成功する**＝クラウド実行環境でもこのリポジトリへの書き込み権限がある。姉妹リポジトリ`cafsjapan-note`向けの別ルーティンは逆に読み取り専用でpushできない仕様になっている点に注意）。
- **投稿頻度は現在、週3回の試験運用中。** 2026-10-05、ユーザーの指示でcron式を`0 8 * * 0,3`（日・水、週2回）から`0 8 * * 1,3,5`（月・水・金、週3回、UTC 8:00=日本時間17:00）に変更した。「投稿数を増やして傾向を早くつかみたい」という理由で、2026-10-07(水)から1か月間の試験的措置。週2回に戻すかどうかはユーザー自身が1か月後に判断する（自動リマインドは不要とのこと）。戻す場合は`RemoteTrigger`の`update`アクションで`cron_expression`を`0 8 * * 0,3`に戻す。
- **2026-10-05、カルーセル準備からリール動画準備へ全面的に書き換え済み。** 内容は上記「リール動画ワークフロー」に準じる（Windsor.aiで過去インサイト確認→テーマ選定→HyperFramesで制作→lint/check→render→git push→**Windsor.aiのexecute_actionは絶対に呼ばず**→Gmailで完成報告・確認依頼、ユーザーの「公開してください」の返信を待つ）。mcp_connectionsにGmail・Windsor-ai・Claude_Code_Remoteの3つを接続済み。
- 同じ仕組みで動いている姉妹ルーティン「note下書き作成・Gmail配信(月木投稿用)」（`trig_01YLBKhm6gBd9dJbXgvZYoqi`、対象リポジトリ`cafsjapan-note`）はInstagramの方針転換と無関係なため変更していない。
- 今後、Instagramのリール自動化ルーティンを調整したい場合は、対話セッションから`RemoteTrigger`（`action: "get"` with `trigger_id: "trig_01KS5qiZj5gZmnFmZHtTkvbQ"`）で直接確認・更新すればよい（`CronCreate`を使う必要はない）。
- **クラウド実行環境のネットワークポリシーに注意（2026-10-07、判明）**：このクラウドルーティンが動くセッションのネットワークアクセスレベル（Limitedと見られる）では、`pixabay.com`・`cdn.jsdelivr.net`・`huggingface.co`への接続がいずれもブロックされる（`EGRESS_BLOCKED`/`403`）。このため素材取得（Pixabay）とBGM生成（MusicGen、Hugging Face経由でモデルをダウンロード）がクラウドルーティンからは実行できない。ローカルPCでの手動制作ではこれらは問題なく動く（ユーザー環境は別のネットワークポリシー）。
  - 対処：`cdn.jsdelivr.net`経由のgsap読み込みは、`npm install gsap`（`registry.npmjs.org`は許可リストに含まれるため成功する）でプロジェクトにインストールし、`node_modules/gsap/dist/gsap.min.js`をプロジェクト内`vendor/`にコピーして`<script src="vendor/gsap.min.js">`のようにローカル参照すれば回避できる。
  - Pixabay・MusicGenはこの回避策が効かない（API/モデルダウンロード自体がブロック対象のため）。この場合はCLAUDE.mdの既存方針通り「失敗時は処理を止めずにフォールバック」する（実写素材なし→CSS/SVGアイコンで画面の余白を埋める、BGMなし→無音のまま進める）。ユーザーにはメールで、どの制約が原因で何を省略したかを明記する。
  - 恒久対処が必要な場合は、ユーザー自身がこの環境の「Network access」設定（環境メニュー→Edit）で`pixabay.com`・`huggingface.co`を許可ドメインに追加する必要がある（`https://code.claude.com/docs/en/cloud-environments#network-access`）。
