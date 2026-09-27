-- 初期データ（assets/pins.json と同じ5件）
INSERT INTO pins (id, title, description, lat, lng) VALUES
  ('tenjin_station', '天神駅',   '福岡市地下鉄空港線',            33.5913, 130.3989),
  ('kego_shrine',    '警固神社', '天神の中心にある神社',          33.5885, 130.3984),
  ('fukuoka_castle', '福岡城跡', '舞鶴公園内の城跡',              33.5846, 130.3829),
  ('ohori_park',     '大濠公園', '池を中心とした大きな公園',      33.5862, 130.3764),
  ('yakuin_station', '薬院駅',   '西鉄天神大牟田線・地下鉄七隈線', 33.5810, 130.4020);
