/**
 * 客户端半侧的离线加载测试：用假 window/document/react 跑一遍 factory 与 apply，
 * 确认模块注册 id、slot 注册、样式注入都按约定发生。
 * 运行：node test/client-load.mjs
 */
import { pathToFileURL } from 'node:url'
import path from 'node:path'

const captured = []
globalThis.window = {
  __ModuleLoader__: {
    load(spec) {
      captured.push(spec)
    },
  },
  addEventListener() {},
  removeEventListener() {},
  getSelection() {
    return null
  },
  innerWidth: 1440,
  innerHeight: 900,
}

globalThis.document = {
  baseURI: 'dsh-app://app/',
  querySelector() {
    return null
  },
  addEventListener() {},
  removeEventListener() {},
  createElement() {
    return { dataset: {}, textContent: '', remove() {} }
  },
  head: { appendChild() {} },
}

globalThis.location = { href: 'dsh-app://app/' }
Object.defineProperty(globalThis, 'navigator', {
  configurable: true,
  value: { clipboard: { writeText: async () => {} } },
})
globalThis.setTimeout = globalThis.setTimeout
globalThis.fetch = async () => {
  throw new Error('not used')
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

const file = path.resolve(process.cwd(), 'client.js')
await import(pathToFileURL(file).href)

check('调用了 __ModuleLoader__.load', captured.length === 1)
const spec = captured[0] ?? {}
check('模块 id 等于包名', spec.id === 'dsh-quick-ask', String(spec.id))
check('factory 是函数', typeof spec.factory === 'function')

const fakeReact = {
  Fragment: Symbol('Fragment'),
  createElement(type, props, ...children) {
    return { type, props: props ?? {}, children }
  },
  useState(initial) {
    return [typeof initial === 'function' ? initial() : initial, () => {}]
  },
  useEffect() {},
  useMemo(factory) {
    return factory()
  },
  useRef(value) {
    return { current: value }
  },
  useCallback(fn) {
    return fn
  },
}

const plugin = spec.factory((name) => {
  if (name === 'react') return fakeReact
  throw new Error('unexpected require: ' + name)
})

check('返回插件对象', plugin !== null && typeof plugin === 'object')
check('插件声明 inject slots', Array.isArray(plugin.inject) && plugin.inject.includes('slots'))

const registrations = []
const injected = []
const effects = []
const ctx = {
  effect(fn, label) {
    effects.push(label)
    return fn()
  },
  slots: {
    inject(name, callback) {
      injected.push(name)
      callback()
    },
    register(options, component) {
      registrations.push({ options, component })
      return () => {}
    },
  },
  locale: { getSnapshot: () => ({ active: 'zh' }) },
}

plugin.apply(ctx)

check('注入了 conversation.input.left', injected.includes('conversation.input.left'), JSON.stringify(injected))
check('注册了两个挂载点', registrations.length === 2, String(registrations.length))
check(
  '挂载点正确',
  registrations.map((r) => r.options?.name).sort().join(',') === 'conversation.composer.dock,conversation.input.left',
  JSON.stringify(registrations.map((r) => r.options?.name)),
)
check('注册 id 带命名空间', registrations.every((r) => String(r.options?.id ?? '').startsWith('quick-ask:')))
check('组件是函数', registrations.every((r) => typeof r.component === 'function'))
check('注册了样式 effect', effects.some((label) => String(label).includes('style')), JSON.stringify(effects))

// 渲染一次（收起态），确认组件体不抛错
const View = registrations[0]?.component
try {
  const tree = View({})
  check('收起态能渲染', tree !== undefined && tree !== null)
} catch (error) {
  check('收起态能渲染', false, String(error && error.message))
}

console.log(failures === 0 ? '\n全部通过' : '\n失败 ' + failures + ' 项')
process.exit(failures === 0 ? 0 : 1)
