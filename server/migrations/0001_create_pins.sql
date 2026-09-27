-- ピンを保存するテーブル
CREATE TABLE IF NOT EXISTS pins (
  id          TEXT PRIMARY KEY,
  title       TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  lat         REAL NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng         REAL NOT NULL CHECK (lng BETWEEN -180 AND 180),
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 表示範囲（緯度・経度）での検索用
CREATE INDEX IF NOT EXISTS idx_pins_lat_lng ON pins (lat, lng);
