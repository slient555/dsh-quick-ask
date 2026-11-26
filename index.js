/**
 * dsh-quick-ask —— 悬浮快速问答插件的宿主半侧。
 *
 * 职责只有一件事：把「一个问题 + 可选引用原文」交给当前默认模型，把答案流式送回去。
 * 不写会话日志、不碰主对话，纯旁路，关掉插件就是彻底消失。
 *
 * 传输：`POST /dsh-quick-ask/ask`（`kind: 'exact'`），带 `accept: text/event-stream`
 * 时走 SSE，否则一次性返回 JSON。桌面端 dsh-app:// 的自定义协议会把该路径转发给宿主。
 */

/** 宿主路由（客户端用同名字段拼接）。 */
const ROUTE = '/dsh-quick-ask/ask'
/** 诊断：客户端模块是否真的物化过。 */
const ROUTE_STATE = '/dsh-quick-ask/state'
/** 客户端每次加载时打一个点。 */
const ROUTE_PING = '/dsh-quick-ask/ping'
/** 请求体上限，防止误传大文件把进程拖住。 */
const MAX_BODY_BYTES = 256 * 1024
/** 带进上下文的历史条数上限（最近 N 条）。 */
const HISTORY_LIMIT = 12
/** 单条历史消息的字符上限。 */
const MESSAGE_LIMIT = 6000
/** 默认系统提示词：短、直给，适合做题时随时打断。 */
const DEFAULT_SYSTEM = [
  '你是用户身边的快速答疑助手，用户可能正在写作业、读文档，随时会打断你来问一句。',
  '要求：',
  '1. 先用一句话给出结论或答案，再给关键步骤；不要客套、不要复述题目、不要写「好的」「当然可以」。',
  '2. 数学与公式用纯文本表达（例如 x^2、sqrt(2)、a/b），不要依赖富文本渲染。',
  '3. 用户给了「选中的原文」时，先判断它是什么（题目、公式、代码、段落），再据此回答。',
  '4. 不确定就说不确定，并给出你判断所需的额外信息；不要编造数据或来源。',
  '5. 篇幅克制：普通问题 3~8 行，复杂问题再展开。',
  '6. 不要使用 Markdown 标记（**、##、反引号、表格），直接输出纯文本与换行。',
].join('\n')

export const name = 'quick-ask'
export const inject = ['llm', 'webServer']

/** 读配置：全部可选，缺省走模型的默认选择。 */
function normalizeConfig(config) {
  const source = config !== null && typeof config === 'object' ? config : {}
  const num = (value, fallback, min, max) => {
    const n = Number(value)
    if (!Number.isFinite(n)) return fallback
    return Math.min(max, Math.max(min, Math.round(n)))
  }
  return {
    provider: typeof source.provider === 'string' ? source.provider.trim() : '',
    model: typeof source.model === 'string' ? source.model.trim() : '',
    system: typeof source.system === 'string' && source.system.trim() !== '' ? source.system : DEFAULT_SYSTEM,
    maxTokens: num(source.maxTokens, 1200, 64, 8000),
    temperature: Math.min(1.5, Math.max(0, Number(source.temperature) || 0.3)),
  }
}

/** 文本安全截断（按字符，不切坏代理对）。 */
function clip(value, limit) {
  const text = typeof value === 'string' ? value : ''
  if (text.length <= limit) return text
  return text.slice(0, limit)
}

/** 把失败对象翻成一句人话。 */
function failureMessage(failure) {
  if (failure === null || failure === undefined) return '模型调用失败（无详情）'
  if (typeof failure === 'string') return failure
  const code = typeof failure.code === 'string' ? failure.code : ''
  const detail = typeof failure.message === 'string' ? failure.message : ''
  const known = {
    NO_ADAPTER: '没有找到该模型的提供方，请在设置里换一个默认模型。',
    MISSING_CREDENTIAL: '模型凭据缺失，请先在设置里登录或填 API Key。',
    AUTH: '模型鉴权失败，请重新登录账号。',
    RATE_LIMIT: '请求太频繁，稍等一下再问。',
    QUOTA: '额度不足，先充个值或换一个模型。',
    ACCOUNT_QUOTA: '账号额度不足。',
    CONTEXT_WINDOW_EXCEEDED: '上下文超长了，清空一下再问。',
  }
  const human = known[code]
  if (human !== undefined) return human
  if (detail !== '') return detail
  return code !== '' ? `模型调用失败：${code}` : '模型调用失败'
}

/**
 * 诊断：把浏览器侧模块图里属于本插件的那一行捞出来，确认宿主是否把它组进了启动图。
 * 服务或字段名对不上时只返回降级信息，绝不抛错。
 */
function probeClientModules(ctx) {
  const service = ctx.get('clientModules', false)
  if (service === undefined || service === null) return { present: false }
  const summary = { present: true, selfRow: null, batch: null, totalRows: 0 }
  try {
    const graph = service.composed ?? service.graph ?? service.snapshot?.()
    const modules = graph?.modules ?? graph?.table
    const rows = Array.isArray(modules) ? modules : modules instanceof Map ? [...modules.values()] : []
    summary.totalRows = rows.length
    for (const row of rows) {
      if (row === null || typeof row !== 'object') continue
      if (row.id === 'dsh-quick-ask') {
        summary.selfRow = { id: row.id, rev: row.rev, inject: row.inject, immediately: row.immediately }
      }
    }
    const batches = Array.isArray(graph?.batches) ? graph.batches : []
    for (const batch of batches) {
      const entries = Array.isArray(batch?.entries) ? batch.entries : []
      if (entries.includes('dsh-quick-ask')) summary.batch = { phase: batch.phase, entries: entries.length }
    }
  } catch (error) {
    summary.error = String(error instanceof Error ? error.message : error)
  }
  return summary
}

/** 解析默认模型：配置优先，其次当前默认选择。 */async function resolveTarget(ctx, settings) {
  if (settings.provider !== '' && settings.model !== '') {
    return { provider: settings.provider, model: settings.model }
  }
  const service = ctx.get('agentDefaultModel', false)
  if (service !== undefined && service !== null && typeof service.currentSelection === 'function') {
    try {
      const selection = await service.currentSelection()
      const provider = selection !== null && typeof selection === 'object' ? selection.provider : undefined
      const model = selection !== null && typeof selection === 'object' ? selection.model : undefined
      if (typeof provider === 'string' && provider !== '' && typeof model === 'string' && model !== '') {
        return { provider, model }
      }
    } catch {
      // 解析失败就落到下面的兜底
    }
  }
  return undefined
}

/** 拼消息：历史（最近 N 条）+ 引用原文 + 本次提问。 */
function buildMessages(payload, question, quote) {
  const messages = []
  const history = Array.isArray(payload?.history) ? payload.history.slice(-HISTORY_LIMIT) : []
  for (const item of history) {
    if (item === null || typeof item !== 'object') continue
    const role = item.role === 'assistant' ? 'assistant' : 'user'
    const text = clip(typeof item.text === 'string' ? item.text : '', MESSAGE_LIMIT).trim()
    if (text === '') continue
    messages.push({ role, content: [{ type: 'text', text }] })
  }
  const parts = []
  if (quote !== '') {
    parts.push('【用户选中的原文】')
    parts.push(clip(quote, MESSAGE_LIMIT))
    parts.push('')
    parts.push('【用户的问题】')
  }
  parts.push(question)
  messages.push({ role: 'user', content: [{ type: 'text', text: parts.join('\n') }] })
  return messages
}

/** 读 JSON 请求体，带大小限制。 */
function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = []
    let size = 0
    req.on('data', (chunk) => {
      size += chunk.length
      if (size > MAX_BODY_BYTES) {
        reject(new Error('too-large'))
        req.destroy()
        return
      }
      chunks.push(chunk)
    })
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8')
      if (raw.trim() === '') {
        resolve({})
        return
      }
      try {
        resolve(JSON.parse(raw))
      } catch {
        reject(new Error('bad-json'))
      }
    })
    req.on('error', reject)
  })
}

function writeJson(res, status, body) {
  if (res.writableEnded === true) return
  const text = JSON.stringify(body)
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'content-length': Buffer.byteLength(text),
  })
  res.end(text)
}

function writeSseHead(res) {
  res.writeHead(200, {
    'content-type': 'text/event-stream; charset=utf-8',
    'cache-control': 'no-store, no-transform',
    connection: 'keep-alive',
    'x-accel-buffering': 'no',
  })
  if (typeof res.flushHeaders === 'function') res.flushHeaders()
}

function writeSse(res, payload) {
  if (res.writableEnded === true) return
  try {
    res.write(`data: ${JSON.stringify(payload)}\n\n`)
  } catch {
    // 客户端已断开：由 close 监听负责收尾
  }
}

/**
 * 安装入口。
 * @param {import('@deepseek-ai/cordis').Context} ctx
 * @param {Record<string, unknown>} [config]
 */
export function apply(ctx, config) {
  const settings = normalizeConfig(config)
  /** 诊断记录：客户端模块何时物化、来自哪。 */
  const runtime = { loadedAt: 0, agent: '', pings: 0, bootedAt: Date.now(), diag: null }

  ctx.effect(() =>
    ctx.webServer.register({
      kind: 'exact',
      path: ROUTE,
      handler(req, res) {
        void handleAsk(ctx, settings, req, res)
      },
    }),
  )

  ctx.effect(() =>
    ctx.webServer.register({
      kind: 'exact',
      path: ROUTE_STATE,
      handler(req, res) {
        writeJson(res, 200, {
          ok: true,
          bootedAt: runtime.bootedAt,
          clientLoadedAt: runtime.loadedAt,
          clientLoaded: runtime.loadedAt > 0,
          clientAgent: runtime.agent,
          pings: runtime.pings,
          clientModule: 'dsh-quick-ask',
          model: `${settings.provider || 'auto'}/${settings.model || 'auto'}`,
          diag: runtime.diag ?? null,
          graph: probeClientModules(ctx),
        })
      },
    }),
  )

  ctx.effect(() =>
    ctx.webServer.register({
      kind: 'exact',
      path: ROUTE_PING,
      handler(req, res) {
        if (req.method !== 'POST') {
          res.setHeader('allow', 'POST')
          writeJson(res, 405, { error: 'method-not-allowed' })
          return
        }
        runtime.loadedAt = Date.now()
        runtime.pings += 1
        runtime.agent = String(req.headers['user-agent'] ?? '').slice(0, 200)
        void readJsonBody(req)
          .then((payload) => {
            runtime.diag = payload
          })
          .catch(() => {})
        writeJson(res, 200, { ok: true, at: runtime.loadedAt })
      },
    }),
  )

  /** 供调试/自测：直接问一次，返回纯文本。 */
  async function ask(question, options = {}) {
    const target = await resolveTarget(ctx, settings)
    if (target === undefined) throw new Error('没有可用的默认模型')
    const controller = new AbortController()
    const messages = buildMessages({ history: options.history }, String(question ?? ''), String(options.quote ?? ''))
    const stream = ctx.llm.stream({
      provider: target.provider,
      model: target.model,
      system: settings.system,
      messages,
      temperature: settings.temperature,
      maxTokens: settings.maxTokens,
      signal: controller.signal,
    })
    let answer = ''
    for await (const chunk of stream) {
      if (chunk?.type === 'text-delta' && typeof chunk.text === 'string') answer += chunk.text
      else if (chunk?.type === 'finish' && (chunk.reason?.kind === 'error' || chunk.reason?.kind === 'aborted')) {
        throw new Error(failureMessage(chunk.reason?.failure))
      }
    }
    return answer
  }

  return { route: ROUTE, ask }
}

/** 路由主流程。 */
async function handleAsk(ctx, settings, req, res) {
  if (req.method !== 'POST') {
    res.setHeader('allow', 'POST')
    writeJson(res, 405, { error: 'method-not-allowed' })
    return
  }

  let payload
  try {
    payload = await readJsonBody(req)
  } catch (error) {
    const tooLarge = error instanceof Error && error.message === 'too-large'
    writeJson(res, tooLarge ? 413 : 400, { error: tooLarge ? 'payload-too-large' : 'bad-json' })
    return
  }

  const question = clip(typeof payload?.question === 'string' ? payload.question : '', MESSAGE_LIMIT).trim()
  if (question === '') {
    writeJson(res, 400, { error: 'empty-question', message: '问题是空的。' })
    return
  }
  const quote = clip(typeof payload?.quote === 'string' ? payload.quote : '', MESSAGE_LIMIT).trim()

  const target = await resolveTarget(ctx, settings)
  if (target === undefined) {
    writeJson(res, 503, { error: 'no-model', message: '没有可用的默认模型：先去设置里选一个模型。' })
    return
  }

  const wantsStream =
    payload?.stream === true || String(req.headers.accept ?? '').toLowerCase().includes('text/event-stream')

  const controller = new AbortController()
  const onClose = () => controller.abort()
  res.on('close', onClose)

  try {
    const stream = ctx.llm.stream({
      provider: target.provider,
      model: target.model,
      system: settings.system,
      messages: buildMessages(payload, question, quote),
      temperature: settings.temperature,
      maxTokens: settings.maxTokens,
      signal: controller.signal,
    })

    let answer = ''
    if (wantsStream === true) writeSseHead(res)

    for await (const chunk of stream) {
      if (chunk?.type === 'text-delta' && typeof chunk.text === 'string' && chunk.text !== '') {
        answer += chunk.text
        if (wantsStream === true) writeSse(res, { type: 'delta', text: chunk.text })
        continue
      }
      if (chunk?.type !== 'finish') continue
      const kind = chunk.reason?.kind
      if (kind === 'error' || kind === 'aborted') {
        const message = failureMessage(chunk.reason?.failure)
        if (wantsStream === true) {
          writeSse(res, { type: 'error', message })
          if (res.writableEnded !== true) res.end()
        } else {
          writeJson(res, 502, { error: 'llm-failed', message })
        }
        return
      }
    }

    if (wantsStream === true) {
      writeSse(res, { type: 'done', model: `${target.provider}/${target.model}` })
      if (res.writableEnded !== true) res.end()
    } else {
      writeJson(res, 200, { answer, model: `${target.provider}/${target.model}` })
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    if (wantsStream === true) {
      writeSse(res, { type: 'error', message: message === 'This operation was aborted' ? '已停止' : message })
      if (res.writableEnded !== true) res.end()
    } else {
      writeJson(res, 500, { error: 'internal', message })
    }
  } finally {
    res.off('close', onClose)
  }
}
