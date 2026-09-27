import { Hono, type Context } from 'hono'
import { cors } from 'hono/cors'
import type { ContentfulStatusCode } from 'hono/utils/http-status'

// 実装ステップ1: D1 に移行するまでは Flutter と同じ assets/pins.json を固定で返す
import pinsData from '../../assets/pins.json'

type Pin = {
  id: string
  title: string
  description: string
  lat: number
  lng: number
}

const pins: Pin[] = pinsData.pins

const app = new Hono()

// 開発中は全オリジンを許可する。本番では許可するオリジンを絞る（api-spec.md 7章）
app.use('/api/*', cors())

// Hono の c.json() は charset を付けないため、仕様どおり UTF-8 を明示する
app.use('*', async (c, next) => {
  await next()
  if (c.res.headers.get('Content-Type') === 'application/json') {
    c.res.headers.set('Content-Type', 'application/json; charset=utf-8')
  }
})

const errorResponse = (
  c: Context,
  status: ContentfulStatusCode,
  code: string,
  message: string,
) => c.json({ error: { code, message } }, status)

app.get('/api/health', (c) => c.json({ status: 'ok' }))

app.get('/api/pins', (c) => {
  c.header('Cache-Control', 'public, max-age=60')
  return c.json({ pins })
})

app.get('/api/pins/:id', (c) => {
  const pin = pins.find((p) => p.id === c.req.param('id'))
  if (!pin) return errorResponse(c, 404, 'not_found', 'pin not found')
  c.header('Cache-Control', 'public, max-age=60')
  return c.json(pin)
})

// 上の GET 以外のメソッドで来たものは 405 にする
app.all('/api/pins', (c) =>
  errorResponse(c, 405, 'method_not_allowed', 'method not allowed'),
)
app.all('/api/pins/:id', (c) =>
  errorResponse(c, 405, 'method_not_allowed', 'method not allowed'),
)

app.notFound((c) => errorResponse(c, 404, 'not_found', 'not found'))

app.onError((err, c) => {
  console.error(err)
  return errorResponse(c, 500, 'internal_error', 'internal server error')
})

export default app
