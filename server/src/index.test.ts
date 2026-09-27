import { describe, expect, it } from 'vitest'

import app from './index'

describe('GET /api/health', () => {
  it('status: ok を返す', async () => {
    const res = await app.request('/api/health')

    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ status: 'ok' })
  })
})

describe('GET /api/pins', () => {
  it('{ pins: [...] } 形式でピン一覧を返す', async () => {
    const res = await app.request('/api/pins')
    const body = (await res.json()) as { pins: { id: string; title: string }[] }

    expect(res.status).toBe(200)
    expect(res.headers.get('content-type')).toBe(
      'application/json; charset=utf-8',
    )
    expect(res.headers.get('cache-control')).toBe('public, max-age=60')
    expect(body.pins).toHaveLength(5)
    expect(body.pins[0]?.title).toBe('天神駅')
  })

  it('CORS ヘッダーを付ける', async () => {
    const res = await app.request('/api/pins', {
      headers: { Origin: 'http://localhost:3000' },
    })

    expect(res.headers.get('access-control-allow-origin')).toBe('*')
  })

  it('GET 以外は 405 を返す', async () => {
    const res = await app.request('/api/pins', { method: 'POST' })

    expect(res.status).toBe(405)
    expect(await res.json()).toEqual({
      error: { code: 'method_not_allowed', message: 'method not allowed' },
    })
  })
})

describe('GET /api/pins/:id', () => {
  it('該当するピンを1件返す', async () => {
    const res = await app.request('/api/pins/ohori_park')
    const body = (await res.json()) as { id: string; title: string }

    expect(res.status).toBe(200)
    expect(body.title).toBe('大濠公園')
  })

  it('存在しない ID は 404 を返す', async () => {
    const res = await app.request('/api/pins/unknown')

    expect(res.status).toBe(404)
    expect(await res.json()).toEqual({
      error: { code: 'not_found', message: 'pin not found' },
    })
  })
})

describe('未定義のパス', () => {
  it('404 を返す', async () => {
    const res = await app.request('/unknown')

    expect(res.status).toBe(404)
  })
})
