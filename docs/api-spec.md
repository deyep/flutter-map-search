# ピンAPI仕様（Cloudflare Workers + D1）

Flutterマップ検索アプリのピンを、ローカルの `assets/pins.json` からサーバーAPI経由の取得に切り替えるための仕様。

- ステータス: 実装中（一覧・1件取得は本番公開済み。検索は未実装）
- 最終更新: 2026-09-27

## 1. 全体構成


| 要素     | 採用技術                                    | 役割               |
| ------ | --------------------------------------- | ---------------- |
| API    | Cloudflare Workers（TypeScript + Hono）   | ピン一覧・検索のHTTP API |
| DB     | Cloudflare D1（SQLite互換）                 | ピンデータの保存         |
| クライアント | Flutter（`google_maps_flutter` + `http`） | 取得したピンをマーカー表示    |


サーバー側のパッケージ（`server/package.json`）:

| パッケージ                       | 種別   | 用途                                       |
| --------------------------- | ---- | ---------------------------------------- |
| `hono`                      | 本番   | ルーティング・JSONレスポンス・CORS                    |
| `wrangler`                  | 開発   | ローカル実行・デプロイ・D1操作                         |
| `vitest`                    | 開発   | テスト                                      |
| `typescript`                | 開発   | 型チェックのみ（変換は wrangler / vitest が行う）         |
| `@cloudflare/workers-types` | 開発   | `D1Database` など Workers 固有の型             |
| `@types/node`               | 開発   | テストでマイグレーションファイルを読むための型                  |

Node.js は 22.12 以上が必要（wrangler・vitest の要件）。開発環境では v24.21.0 を使用。

リポジトリ構成（モノレポ）:

```
flutter-map-search/
├── lib/
│   ├── main.dart            # 地図画面（MapPage）
│   ├── pin.dart             # Pin モデルと JSON パース
│   └── pin_repository.dart  # ピンの取得元（assets / API）
├── assets/pins.json         # API_BASE_URL 未指定時に使うローカルデータ
├── config/                  # 接続先ごとの API_BASE_URL（--dart-define-from-file 用）
│   ├── local.json
│   ├── local-android.json
│   └── prod.json
├── .vscode/launch.json      # 接続先ごとの VS Code 起動設定
├── docs/api-spec.md         # この仕様書
└── server/                  # Cloudflare Worker
    ├── src/index.ts
    ├── src/index.test.ts
    ├── migrations/
    │   ├── 0001_create_pins.sql
    │   └── 0002_seed_pins.sql
    ├── package.json
    └── wrangler.toml
```



## 2. ベースURL


| 環境                    | URL                                                 | Flutter の設定ファイル |
| --------------------- | --------------------------------------------------- | --------------- |
| ローカル（iOSシミュレータ / Web） | `http://localhost:8787`                             | `config/local.json` |
| ローカル（Androidエミュレータ）   | `http://10.0.2.2:8787`                              | `config/local-android.json` |
| 本番                    | `https://map-search-api.ideyep.workers.dev`（将来カスタムドメイン） | `config/prod.json` |


Flutter側には `API_BASE_URL` をビルド時に渡す。指定しない場合は `assets/pins.json` を読む。

```
flutter run --dart-define-from-file=config/local.json   # ローカル
flutter run --dart-define-from-file=config/prod.json    # 本番
flutter run                                             # assets（サーバーなし）
```

- VS Code では `.vscode/launch.json` の「Local (iOS Simulator)」「Local (Android Emulator)」「Prod」「Assets (offline)」から選んで起動する。
- 値はビルド時に埋め込まれるため、接続先の切り替えはホットリロードでは反映されない。アプリを停止して起動し直す。
- `config/*.json` は Git 管理される。APIキーなどの秘密の値は入れない（→ 7. セキュリティ）。

## 3. データモデル



### Pin


| フィールド         | 型      | 必須  | 説明                                |
| ------------- | ------ | --- | --------------------------------- |
| `id`          | string | ○   | 一意なID（スネークケース。例:`tenjin_station`） |
| `title`       | string | ○   | 表示名（InfoWindowのタイトル）              |
| `description` | string | ○   | 説明（InfoWindowのスニペット）              |
| `lat`         | number | ○   | 緯度（-90〜90）                        |
| `lng`         | number | ○   | 経度（-180〜180）                      |


`Pin.fromJson` がパースする形。`assets/pins.json` とAPIのレスポンスは、どちらもこのPinの配列を `{ "pins": [...] }` で包んだ形に揃え、Flutter側は同じパース処理（`Pin.listFromJsonString`）を使う。

## 4. エンドポイント



### 4.1 `GET /api/pins` — ピン一覧・検索

クエリパラメータ（すべて省略可能）:


| パラメータ               | 型       | 説明                                   |
| ------------------- | ------- | ------------------------------------ |
| `minLat` / `maxLat` | number  | 表示範囲の緯度の下限・上限                        |
| `minLng` / `maxLng` | number  | 表示範囲の経度の下限・上限                        |
| `q`                 | string  | キーワード（`title` と `description` の部分一致） |
| `limit`             | integer | 最大件数（初期値 100、上限 500）                 |


- 範囲のパラメータは4つそろったときだけ有効。一部だけ指定された場合は `400` を返す。
- パラメータを指定しなければ全件を返す（`limit` の範囲内）。

> **実装状況**: クエリパラメータは未実装（実装ステップ4）。現在はパラメータを無視し、`ORDER BY id LIMIT 100` で返す。

レスポンス `200 OK`（`Content-Type: application/json; charset=utf-8`、`Cache-Control: public, max-age=60`）:

```json
{
  "pins": [
    {
      "id": "tenjin_station",
      "title": "天神駅",
      "description": "福岡市地下鉄空港線",
      "lat": 33.5913,
      "lng": 130.3989
    }
  ]
}
```

> トップレベルをオブジェクトにしておき、ページングなどのメタ情報が必要になったら `{ "pins": [...], "next": ... }` のようにフィールドを足す。既存のクライアントは `pins` だけを読むので壊れない。

例:

```
GET /api/pins
GET /api/pins?minLat=33.58&maxLat=33.60&minLng=130.37&maxLng=130.41
GET /api/pins?q=駅
```



### 4.2 `GET /api/pins/:id` — ピン1件

- `200 OK`: Pinオブジェクト1件（`Cache-Control: public, max-age=60`）
- `404 Not Found`: 該当なし（`{ "error": { "code": "not_found", "message": "pin not found" } }`）



### 4.3 `GET /api/health` — 死活確認

- `200 OK`: `{ "status": "ok" }`



### 4.4 書き込みAPI（将来）

`POST /api/pins`、`PUT /api/pins/:id`、`DELETE /api/pins/:id` は、認証を入れてから実装する（→ 7. セキュリティ）。

## 5. エラーレスポンス

形式を統一する:

```json
{ "error": { "code": "invalid_params", "message": "bbox requires minLat, maxLat, minLng, maxLng" } }
```


| HTTP | code                 | 発生条件                   |
| ---- | -------------------- | ---------------------- |
| 400  | `invalid_params`     | パラメータの型・範囲が不正、範囲指定が不完全 |
| 404  | `not_found`          | ピンまたはパスが存在しない          |
| 405  | `method_not_allowed` | 対応していないHTTPメソッド        |
| 500  | `internal_error`     | DBエラーなど                |


- エラーレスポンスにも `Content-Type: application/json; charset=utf-8` を付ける。Hono の `c.json()` は charset を付けないため、ミドルウェアで補う。
- 500 のときはレスポンスに内部の詳細を含めず、`console.error` でログにだけ出す。
- `400 invalid_params` は検索パラメータとあわせて実装する（実装ステップ4）。



## 6. D1スキーマ

`server/migrations/0001_create_pins.sql`:

```sql
CREATE TABLE IF NOT EXISTS pins (
  id          TEXT PRIMARY KEY,
  title       TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  lat         REAL NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng         REAL NOT NULL CHECK (lng BETWEEN -180 AND 180),
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_pins_lat_lng ON pins (lat, lng);
```

初期データ（`server/migrations/0002_seed_pins.sql`）:

```sql
INSERT INTO pins (id, title, description, lat, lng) VALUES
  ('tenjin_station', '天神駅',   '福岡市地下鉄空港線',            33.5913, 130.3989),
  ('kego_shrine',    '警固神社', '天神の中心にある神社',          33.5885, 130.3984),
  ('fukuoka_castle', '福岡城跡', '舞鶴公園内の城跡',              33.5846, 130.3829),
  ('ohori_park',     '大濠公園', '池を中心とした大きな公園',      33.5862, 130.3764),
  ('yakuin_station', '薬院駅',   '西鉄天神大牟田線・地下鉄七隈線', 33.5810, 130.4020);
```

範囲検索のクエリ:

```sql
SELECT id, title, description, lat, lng
FROM pins
WHERE lat BETWEEN ?1 AND ?2
  AND lng BETWEEN ?3 AND ?4
  AND (?5 IS NULL OR title LIKE '%' || ?5 || '%' OR description LIKE '%' || ?5 || '%')
ORDER BY id
LIMIT ?6;
```

`created_at` と `updated_at` はAPIのレスポンスには含めない。

`wrangler.toml`（抜粋）:

```toml
name = "map-search-api"
main = "src/index.ts"
compatibility_date = "2026-09-01"

[[d1_databases]]
binding = "DB"
database_name = "map-search-db"
database_id = "3511d3d1-290f-400a-9f00-b676bee730c8"
migrations_dir = "migrations"
```

- Worker名・D1名は、Flutter専用ではなくサービス全体のものとして `map-search-` で始める。
- D1はサービス全体のDBとし、今後のテーブル（ユーザー、お気に入りなど）も同じDBに追加する。
- ローカル開発では `npm run db:migrate:local` で `server/.wrangler/` 内のD1に、本番は `npm run db:migrate:remote` で本番のD1にマイグレーションを適用する。
- ローカルのD1は `database_id` ごとに別のDBとして作られるため、`database_id` を変えたら `npm run db:migrate:local` をやり直す。
- テストはwranglerの `getPlatformProxy()` でメモリ上のD1を用意し、マイグレーションを適用してから実行する。



## 7. セキュリティ・運用

- 読み取りAPIは認証なしで公開する。
- 書き込みAPIには、Cloudflare Access または `Authorization: Bearer <token>` による認証をかける。トークンは `wrangler secret put` で管理し、アプリには埋め込まない。
- CORS: Flutter Webで使う場合に備えて `Access-Control-Allow-Origin` を付ける。開発中は `*`、本番では許可するオリジンを絞る。`OPTIONS` のプリフライトにも応答する。
  - **現状**: 本番も `*` のまま。読み取り専用のため許容し、書き込みAPIや認証を追加する時点で絞る。
- キャッシュ: 読み取りAPIに `Cache-Control: public, max-age=60` を付ける。
- 大量アクセスへの対策が必要になったら、Cloudflareのレート制限ルールを使う。無料プランでは上限（1日10万リクエスト）を超えるとエラーになるだけで課金はされない。
- SQL はプレースホルダ（`?1`）で値を渡し、文字列連結でクエリを組み立てない。

### リポジトリで管理する情報・しない情報

GitHub リポジトリは公開（Public）のため、以下を守る。

| 情報 | 置き場所 | Git 管理 |
| --- | --- | --- |
| Google Maps APIキー | `.env`（iOS は xcconfig、Android は `build.gradle.kts` から読む） | しない |
| Cloudflare のログイン情報 | `~/Library/Preferences/.wrangler/` | しない（リポジトリ外） |
| ローカルのD1・Worker の秘密値 | `server/.wrangler/`・`server/.dev.vars` | しない（`server/.gitignore`） |
| D1 の `database_id`・Worker の URL | `server/wrangler.toml`・`config/prod.json` | する（識別子であり秘密ではない。操作には API トークンが必要） |

- Google Maps APIキーはアプリに埋め込まれるため、Google Cloud Console でアプリ制限（iOS: バンドルID、Android: パッケージ名 + SHA-1）と API 制限（Maps SDK for iOS / Android のみ）をかける。



## 8. Flutter側の変更点

ピンの取得は `lib/pin_repository.dart` の `PinRepository` に集約し、画面（`MapPage`）は `fetchPins()` だけを呼ぶ。


| 実装                   | 取得元                           |
| -------------------- | ----------------------------- |
| `AssetPinRepository` | `assets/pins.json`            |
| `ApiPinRepository`   | `GET {API_BASE_URL}/api/pins` |


1. `pubspec.yaml` に `http` を追加する。（済）
2. `PinRepository` と上記2つの実装を追加する。パースは `Pin.listFromJsonString` を共通で使う。（済）
3. `createPinRepository()` で `API_BASE_URL`（`String.fromEnvironment`）を読み、指定があれば `ApiPinRepository`、なければ `AssetPinRepository` を使う。（済）
4. API取得に失敗したら（200以外・タイムアウト10秒・通信エラー）、assetsには切り替えず、「再試行」付きのSnackBarでエラーを表示する。（済）
5. 範囲検索: `fetchPins` に表示範囲とキーワードの引数を足す。`GoogleMap.onCameraIdle` で `getVisibleRegion()` を呼び、表示範囲をAPIに渡して再取得する（連続した呼び出しはデバウンスする）。
6. 読み込み中の状態を画面に表示する。
7. 接続先ごとの設定ファイル（`config/*.json`）と VS Code の起動設定（`.vscode/launch.json`）を用意する。（済）
8. Android エミュレータからローカルの Worker（`http`）に接続するため、開発ビルドだけ cleartext 通信を許可する。

補足:

- `ApiPinRepository` はレスポンスを `utf8.decode(response.bodyBytes)` で読む（charset がなくても日本語が化けないようにするため）。
- テンプレートの `test/widget_test.dart` は削除済み。テストは `test/pin_test.dart` と `test/pin_repository_test.dart`（`http` の `MockClient` を使用）。



## 9. 実装ステップ

1. **Worker（固定JSON）**: `GET /api/pins` で `pins.json` と同じ内容を返し、`wrangler dev` で動作を確認する。（済）
2. **Flutter接続**: Flutter側の変更点の1〜4を実装し、ローカルのWorkerから表示されることを確認する。（済・iOSシミュレータで確認）
3. **D1移行**: スキーマ作成とデータ投入を行い、Workerを `SELECT` に置き換える（レスポンスの形は変えない）。（済・ローカルのD1で確認）
4. **検索**: 範囲検索と `q` を実装し、Flutter側の変更点の5を実装する。
5. **デプロイ**: `wrangler deploy` を実行し、本番URLで動作を確認する。（済・2026-09-27 に `https://map-search-api.ideyep.workers.dev` へ公開。検索の実装より先に実施。iOSシミュレータから本番への接続も確認）
6. **（任意）CI**: GitHub ActionsでWorkerを自動デプロイする。



## 10. 開発・運用手順

`server/` の npm スクリプト:

| コマンド | 内容 |
| --- | --- |
| `npm run dev` | ローカルで Worker を起動（`http://localhost:8787`）。保存すると自動で再読み込み |
| `npm test` | テスト（vitest）。`getPlatformProxy()` でメモリ上の D1 を使う |
| `npm run typecheck` | 型チェック（`tsc --noEmit`） |
| `npm run db:migrate:local` | ローカルの D1 にマイグレーションを適用 |
| `npm run db:migrate:remote` | 本番の D1 にマイグレーションを適用 |
| `npm run deploy` | 本番に Worker をデプロイ |

ローカル開発の流れ:

1. `server/` で `npm run db:migrate:local`（初回と、マイグレーションを追加したとき）
2. `server/` で `npm run dev`
3. `flutter run --dart-define-from-file=config/local.json`（または VS Code の「Local (iOS Simulator)」）

本番反映の流れ:

1. `npm run typecheck` と `npm test` が通ることを確認する。
2. マイグレーションを追加した場合は `npm run db:migrate:remote` を先に実行する。
3. `npm run deploy` を実行する。
4. `https://map-search-api.ideyep.workers.dev/api/health` と `/api/pins` を確認する。

※ `wrangler login` 済みであること（`npx wrangler whoami` で確認できる）。

データの確認:

- 本番: Cloudflare ダッシュボードの D1 → `map-search-db` →「データを探索」または「コンソール」。コンソールは本番データを直接変更できるため、確認は `SELECT` のみとし、データ変更はマイグレーションで行う。誤操作時は「タイム トラベル」で復元できる。
- CLI: `npx wrangler d1 execute map-search-db --remote --command "SELECT * FROM pins"`（ローカルは `--local`）
- ローカル: `npm run dev` 実行中に `e` キーでローカルエクスプローラーを開く。実体は `server/.wrangler/state/v3/d1/` の SQLite ファイル。

監視:

- Cloudflare ダッシュボードの Workers → `map-search-api` →「メトリクス」で呼び出し数・エラー数・CPU 時間を確認できる（無料プランの CPU 時間上限は 1 回 10ms。現状は約 4ms）。



## 11. 未決事項

- ピンの件数の見込み（数百件を超えるなら、範囲検索に加えてクラスタリングやページングを検討する）
- カスタムドメインを使うかどうか
- 書き込みAPIの利用者（管理画面か、アプリのユーザーか）
- Workers のログ保存（`wrangler.toml` に `[observability] enabled = true` を追加するか）

