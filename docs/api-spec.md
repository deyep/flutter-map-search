# ピンAPI仕様（Cloudflare Workers + D1）

Flutterマップ検索アプリのピンを、ローカルの `assets/pins.json` からサーバーAPI経由の取得に切り替えるための仕様。

- ステータス: ドラフト
- 最終更新: 2026-09-27

## 1. 全体構成


| 要素     | 採用技術                                    | 役割               |
| ------ | --------------------------------------- | ---------------- |
| API    | Cloudflare Workers（TypeScript）          | ピン一覧・検索のHTTP API |
| DB     | Cloudflare D1（SQLite互換）                 | ピンデータの保存         |
| クライアント | Flutter（`google_maps_flutter` + `http`） | 取得したピンをマーカー表示    |


リポジトリ構成（モノレポ）:

```
flutter-map-search/
├── lib/            # Flutterアプリ
├── assets/pins.json  # API_BASE_URL 未指定時に使うローカルデータ
└── server/         # Cloudflare Worker
    ├── src/index.ts
    ├── migrations/0001_create_pins.sql
    └── wrangler.toml
```



## 2. ベースURL


| 環境                    | URL                                                 |
| --------------------- | --------------------------------------------------- |
| ローカル（iOSシミュレータ / Web） | `http://localhost:8787`                             |
| ローカル（Androidエミュレータ）   | `http://10.0.2.2:8787`                              |
| 本番                    | `https://<worker名>.<アカウント>.workers.dev`（将来カスタムドメイン） |


Flutter側には `--dart-define=API_BASE_URL=<URL>` で渡す。

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

レスポンス `200 OK`（`Content-Type: application/json; charset=utf-8`）:

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

- `200 OK`: Pinオブジェクト1件
- `404 Not Found`: 該当なし



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
name = "flutter-map-search-api"
main = "src/index.ts"
compatibility_date = "2026-09-01"

[[d1_databases]]
binding = "DB"
database_name = "pins-db"
database_id = "<wrangler d1 create の出力>"
```



## 7. セキュリティ・運用

- 読み取りAPIは認証なしで公開する。
- 書き込みAPIには、Cloudflare Access または `Authorization: Bearer <token>` による認証をかける。トークンは `wrangler secret put` で管理し、アプリには埋め込まない。
- CORS: Flutter Webで使う場合に備えて `Access-Control-Allow-Origin` を付ける。開発中は `*`、本番では許可するオリジンを絞る。`OPTIONS` のプリフライトにも応答する。
- キャッシュ: 読み取りAPIに `Cache-Control: public, max-age=60` を付ける。
- 大量アクセスへの対策が必要になったら、Cloudflareのレート制限ルールを使う。



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



## 9. 実装ステップ

1. **Worker（固定JSON）**: `GET /api/pins` で `pins.json` と同じ内容を返し、`wrangler dev` で動作を確認する。
2. **Flutter接続**: Flutter側の変更点の1〜4を実装し、ローカルのWorkerから表示されることを確認する。
3. **D1移行**: スキーマ作成とデータ投入を行い、Workerを `SELECT` に置き換える（レスポンスの形は変えない）。
4. **検索**: 範囲検索と `q` を実装し、Flutter側の変更点の5を実装する。
5. **デプロイ**: `wrangler deploy` を実行し、本番URLで動作を確認する。
6. **（任意）CI**: GitHub ActionsでWorkerを自動デプロイする。



## 10. 未決事項

- ピンの件数の見込み（数百件を超えるなら、範囲検索に加えてクラスタリングやページングを検討する）
- カスタムドメインを使うかどうか
- 書き込みAPIの利用者（管理画面か、アプリのユーザーか）

