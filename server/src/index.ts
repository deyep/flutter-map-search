import { Hono, type Context } from 'hono'
import { cors } from 'hono/cors'
import type { ContentfulStatusCode } from 'hono/utils/http-status'

export type Bindings = {
  DB: D1Database
}

type Pin = {
  id: string
  title: string
  description: string
  lat: number
  lng: number
}

// created_at / updated_at はレスポンスに含めない（api-spec.md 6章）
const PIN_COLUMNS = 'id, title, description, lat, lng'

const app = new Hono<{ Bindings: Bindings }>()

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
  c: Context<{ Bindings: Bindings }>,
  status: ContentfulStatusCode,
  code: string,
  message: string,
) => c.json({ error: { code, message } }, status)

app.get('/api/health', (c) => c.json({ status: 'ok' }))

app.get('/api/pins', async (c) => {
  const { results: pins } = await c.env.DB.prepare(
    `SELECT ${PIN_COLUMNS} FROM pins ORDER BY id LIMIT 100`,
  ).all<Pin>()
  c.header('Cache-Control', 'public, max-age=60')
  return c.json({ pins })
})

app.get('/api/pins/:id', async (c) => {
  const pin = await c.env.DB.prepare(
    `SELECT ${PIN_COLUMNS} FROM pins WHERE id = ?1`,
  )
    .bind(c.req.param('id'))
    .first<Pin>()
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
