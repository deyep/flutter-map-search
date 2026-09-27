import { readdir, readFile } from 'node:fs/promises'
import { join } from 'node:path'

import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { getPlatformProxy, type PlatformProxy } from 'wrangler'

import app, { type Bindings } from './index'

// wrangler.toml の D1 設定を元に、テスト用の手元の D1（保存しないメモリ上の DB）を用意する
let proxy: PlatformProxy<Bindings>
let env: Bindings

const applyMigrations = async (db: D1Database) => {
  const dir = join(import.meta.dirname, '../migrations')
  const files = (await readdir(dir)).filter((f) => f.endsWith('.sql')).sort()
  for (const file of files) {
    const sql = await readFile(join(dir, file), 'utf8')
    const statements = sql
      .split(';')
      .map((s) => s.replace(/^\s*--.*$/gm, '').trim())
      .filter((s) => s.length > 0)
    await db.batch(statements.map((s) => db.prepare(s)))
  }
}

beforeAll(async () => {
  proxy = await getPlatformProxy<Bindings>({ persist: false })
  env = proxy.env
  await applyMigrations(env.DB)
})

afterAll(async () => {
  await proxy?.dispose()
})

const request = (path: string, init?: RequestInit) =>
  app.request(path, init, env)

describe('GET /api/health', () => {
  it('status: ok を返す', async () => {
    const res = await request('/api/health')

    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ status: 'ok' })
  })
})

describe('GET /api/pins', () => {
  it('D1 のピン一覧を { pins: [...] } 形式で返す', async () => {
    const res = await request('/api/pins')
    const body = (await res.json()) as { pins: Record<string, unknown>[] }

    expect(res.status).toBe(200)
    expect(res.headers.get('content-type')).toBe(
      'application/json; charset=utf-8',
    )
    expect(res.headers.get('cache-control')).toBe('public, max-age=60')
    expect(body.pins).toHaveLength(5)
    expect(body.pins).toContainEqual({
      id: 'tenjin_station',
      title: '天神駅',
      description: '福岡市地下鉄空港線',
      lat: 33.5913,
      lng: 130.3989,
    })
  })

  it('created_at / updated_at は含めない', async () => {
    const res = await request('/api/pins')
    const body = (await res.json()) as { pins: Record<string, unknown>[] }

    expect(Object.keys(body.pins[0] ?? {}).sort()).toEqual([
      'description',
      'id',
      'lat',
      'lng',
      'title',
    ])
  })

  it('CORS ヘッダーを付ける', async () => {
    const res = await request('/api/pins', {
      headers: { Origin: 'http://localhost:3000' },
    })

    expect(res.headers.get('access-control-allow-origin')).toBe('*')
  })

  it('GET 以外は 405 を返す', async () => {
    const res = await request('/api/pins', { method: 'POST' })

    expect(res.status).toBe(405)
    expect(await res.json()).toEqual({
      error: { code: 'method_not_allowed', message: 'method not allowed' },
    })
  })
})

describe('GET /api/pins/:id', () => {
  it('該当するピンを1件返す', async () => {
    const res = await request('/api/pins/ohori_park')
    const body = (await res.json()) as { id: string; title: string }

    expect(res.status).toBe(200)
    expect(body.title).toBe('大濠公園')
  })

  it('存在しない ID は 404 を返す', async () => {
    const res = await request('/api/pins/unknown')

    expect(res.status).toBe(404)
    expect(await res.json()).toEqual({
      error: { code: 'not_found', message: 'pin not found' },
    })
  })
})

describe('エラー処理', () => {
  it('未定義のパスは 404 を返す', async () => {
    const res = await request('/unknown')

    expect(res.status).toBe(404)
  })

  it('DB のエラーは 500 を返す', async () => {
    const brokenDb = {
      prepare: () => {
        throw new Error('db is down')
      },
    } as unknown as D1Database

    const res = await app.request('/api/pins', undefined, { DB: brokenDb })

    expect(res.status).toBe(500)
    expect(await res.json()).toEqual({
      error: { code: 'internal_error', message: 'internal server error' },
    })
  })
})
