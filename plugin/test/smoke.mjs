/**
 * 离线冒烟测试：不开 DSH，直接拿假的 ctx 跑宿主路由。
 * 运行：node test/smoke.mjs
 */
import { EventEmitter } from 'node:events'
import { apply } from '../index.js'

function makeReq(method, bodyObj, headers = {}) {
  const req = new EventEmitter()
  req.method = method
  req.headers = headers
  const payload = bodyObj === undefined ? '' : JSON.stringify(bodyObj)
  queueMicrotask(() => {
    if (payload !== '') req.emit('data', Buffer.from(payload, 'utf8'))
    req.emit('end')
  })
  return req
}

class FakeRes extends EventEmitter {
  constructor() {
    super()
    this.status = 0
    this.headers = {}
    this.chunks = []
    this.writableEnded = false
  }
  writeHead(status, headers) {
    this.status = status
    this.headers = { ...headers }
  }
  setHeader(name, value) {
    this.headers[name.toLowerCase()] = value
  }
  flushHeaders() {}
  write(text) {
    this.chunks.push(String(text))
    return true
  }
  end(text) {
    if (text !== undefined) this.chunks.push(String(text))
    this.writableEnded = true
    this.emit('close')
  }
  get bodyText() {
    return this.chunks.join('')
  }
}

function makeCtx({ provider = 'deepseek-official', model = 'deepseek-v4-flash', chunks } = {}) {
  const registrations = []
  const captured = []
  const ctx = {
    webServer: {
      register(route) {
        registrations.push(route)
        return () => {}
      },
    },
    effect(fn) {
      const dispose = fn()
      return () => dispose?.()
    },
    get(name) {
      if (name === 'agentDefaultModel') {
        return { currentSelection: async () => ({ provider, model }) }
      }
      return undefined
    },
    llm: {
      async *stream(options) {
        captured.push(options)
        for (const piece of chunks ?? ['第一段', '，第二段']) {
          yield { type: 'text-delta', text: piece }
        }
        yield { type: 'finish', reason: { kind: 'stop' } }
      },
    },
  }
  return { ctx, registrations, captured }
}

function routeOf(registrations, path) {
  const route = registrations.find((r) => r.path === path)
  if (route === undefined) throw new Error('missing route: ' + path)
  return route
}

async function waitFor(predicate, label) {
  for (let i = 0; i < 200; i += 1) {
    if (predicate()) return
    await new Promise((resolve) => setTimeout(resolve, 5))
  }
  throw new Error('timeout waiting for ' + label)
}

let failures = 0
function check(name, condition, detail) {
  if (condition) {
    console.log('ok   ' + name)
    return
  }
  failures += 1
  console.log('FAIL ' + name + (detail === undefined ? '' : ' — ' + detail))
}

// 1. SSE 路径
{
  const { ctx, registrations, captured } = makeCtx()
  apply(ctx, {})
  check('注册了 /ask 路由', registrations.some((r) => r.path === '/dsh-quick-ask/ask'))
  check('/ask 是 exact', routeOf(registrations, '/dsh-quick-ask/ask').kind === 'exact')
  check('注册了 /state 路由', registrations.some((r) => r.path === '/dsh-quick-ask/state'))
  check('注册了 /ping 路由', registrations.some((r) => r.path === '/dsh-quick-ask/ping'))

  const res = new FakeRes()
  const req = makeReq('POST', { question: '为什么这一步可以换元？', quote: 'let u = x + 1' }, { accept: 'text/event-stream' })
  routeOf(registrations, '/dsh-quick-ask/ask').handler(req, res)
  await waitFor(() => res.writableEnded, 'sse end')

  check('SSE 状态码 200', res.status === 200, String(res.status))
  check('SSE content-type', String(res.headers['content-type'] ?? '').includes('text/event-stream'), res.headers['content-type'])
  check('SSE 有 delta', res.bodyText.includes('"type":"delta"'), res.bodyText)
  const deltas = res.bodyText
    .split('\n\n')
    .filter((block) => block.startsWith('data:'))
    .map((block) => JSON.parse(block.slice(5).trim()))
    .filter((event) => event.type === 'delta')
    .map((event) => event.text)
    .join('')
  check('SSE 拼出完整答案', deltas === '第一段，第二段', JSON.stringify(deltas))
  check('SSE 有 done', res.bodyText.includes('"type":"done"'))

  const request = captured[0]
  check('请求带 provider/model', request.provider === 'deepseek-official' && request.model === 'deepseek-v4-flash')
  const lastUser = request.messages[request.messages.length - 1]
  check('引用原文进入提问', lastUser.content[0].text.includes('let u = x + 1') && lastUser.content[0].text.includes('为什么这一步可以换元？'))
  check('system 提示词存在', typeof request.system === 'string' && request.system.length > 20)
}

// 2. JSON 路径
{
  const { ctx, registrations } = makeCtx({ chunks: ['答案是 ', '42'] })
  apply(ctx, {})
  const res = new FakeRes()
  routeOf(registrations, '/dsh-quick-ask/ask').handler(makeReq('POST', { question: '答案是多少' }, { accept: 'application/json' }), res)
  await waitFor(() => res.writableEnded, 'json end')
  const data = JSON.parse(res.bodyText)
  check('JSON 路径答案正确', data.answer === '答案是 42', res.bodyText)
  check('JSON 路径带模型名', data.model === 'deepseek-official/deepseek-v4-flash')
}

// 3. 诊断端点：ping 之后 state 记到客户端
{
  const { ctx, registrations } = makeCtx()
  apply(ctx, {})
  const before = JSON.parse((() => {
    const res = new FakeRes()
    routeOf(registrations, '/dsh-quick-ask/state').handler(makeReq('GET', undefined), res)
    return res.bodyText
  })())
  check('state 初始未加载', before.clientLoaded === false)

  const ping = new FakeRes()
  routeOf(registrations, '/dsh-quick-ask/ping').handler(makeReq('POST', { ua: 'test-agent' }, { 'user-agent': 'test-agent' }), ping)
  const after = JSON.parse((() => {
    const res = new FakeRes()
    routeOf(registrations, '/dsh-quick-ask/state').handler(makeReq('GET', undefined), res)
    return res.bodyText
  })())
  check('ping 后 state 显示已加载', after.clientLoaded === true && after.clientAgent === 'test-agent', JSON.stringify(after))
}

// 4. 空问题
{
  const { ctx, registrations } = makeCtx()
  apply(ctx, {})
  const res = new FakeRes()
  routeOf(registrations, '/dsh-quick-ask/ask').handler(makeReq('POST', { question: '   ' }), res)
  await waitFor(() => res.writableEnded, 'empty')
  check('空问题返回 400', res.status === 400, String(res.status))
}

// 5. 非 POST
{
  const { ctx, registrations } = makeCtx()
  apply(ctx, {})
  const res = new FakeRes()
  routeOf(registrations, '/dsh-quick-ask/ask').handler(makeReq('GET', undefined), res)
  await waitFor(() => res.writableEnded, 'method')
  check('GET 返回 405', res.status === 405, String(res.status))
}

// 6. 没有默认模型
{
  const { ctx, registrations } = makeCtx()
  ctx.get = () => undefined
  apply(ctx, {})
  const res = new FakeRes()
  routeOf(registrations, '/dsh-quick-ask/ask').handler(makeReq('POST', { question: 'hi' }, { accept: 'application/json' }), res)
  await waitFor(() => res.writableEnded, 'no model')
  check('无模型返回 503', res.status === 503, String(res.status))
}

// 7. 模型报错 → SSE error 事件
{
  const { ctx, registrations } = makeCtx()
  ctx.llm.stream = async function* () {
    yield { type: 'finish', reason: { kind: 'error', failure: { code: 'RATE_LIMIT', message: 'slow down' } } }
  }
  apply(ctx, {})
  const res = new FakeRes()
  routeOf(registrations, '/dsh-quick-ask/ask').handler(makeReq('POST', { question: 'hi' }, { accept: 'text/event-stream' }), res)
  await waitFor(() => res.writableEnded, 'llm error')
  check('错误转成人话', res.bodyText.includes('请求太频繁'), res.bodyText)
}

console.log(failures === 0 ? '\n全部通过' : '\n失败 ' + failures + ' 项')
process.exit(failures === 0 ? 0 : 1)
