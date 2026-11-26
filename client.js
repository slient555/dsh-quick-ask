window.__ModuleLoader__.load({
  id: '@slient555/dsh-quick-ask',
  factory(require) {
    const React = require('react')
    const h = React.createElement
    const { useCallback, useEffect, useMemo, useRef, useState } = React

    const NS = 'dsh-quick-ask'
    const STYLE_KEY = NS + '/panel.css'
    const ASK_PATH = 'dsh-quick-ask/ask'

    // ------------------------------------------------------------------ styles

    const CSS = `
.dqa-root { position: fixed; z-index: 900; font-family: inherit; color: var(--dsw-alias-label-primary); }
.dqa-ball {
  position: fixed; right: 24px; bottom: 96px; width: 46px; height: 46px; padding: 0;
  pointer-events: auto; user-select: none;
  display: flex; align-items: center; justify-content: center;
  border: 1px solid var(--dsw-alias-border-l1, rgba(127,142,163,.35));
  border-radius: 16px; cursor: pointer;
  background: var(--dsw-alias-bg-layer-1, #fff);
  color: var(--dsw-alias-brand-primary, #4d6bfe);
  box-shadow: 0 8px 22px rgba(0, 0, 0, .16);
  transition: transform .16s ease, box-shadow .16s ease, border-color .16s ease;
}
.dqa-ball:hover { transform: translateY(-2px); border-color: var(--dsw-alias-brand-primary, #4d6bfe); box-shadow: 0 12px 28px rgba(0, 0, 0, .22); }
.dqa-ball:active { transform: translateY(0) scale(.97); }
.dqa-ball svg { width: 22px; height: 22px; display: block; }

.dqa-trigger {
  display: inline-flex; align-items: center; gap: 5px;
  height: 30px; padding: 0 10px; flex: none;
  border: 1px solid var(--dsw-alias-border-l1, rgba(127,142,163,.35)); border-radius: 999px; cursor: pointer;
  background: var(--dsw-alias-bg-layer-1, transparent); color: var(--dsw-alias-label-secondary, #8a8f98);
  pointer-events: auto; user-select: none;
  transition: color .12s ease, background .12s ease, border-color .12s ease;
}
.dqa-trigger:hover { color: var(--dsw-alias-brand-primary, #4d6bfe); border-color: var(--dsw-alias-brand-primary, #4d6bfe); }
.dqa-trigger-on {
  color: var(--dsw-alias-brand-primary, #4d6bfe);
  border-color: var(--dsw-alias-brand-primary, #4d6bfe);
  background: var(--dsw-alias-bg-layer-2, rgba(127,142,163,.12));
}
.dqa-trigger svg { width: 15px; height: 15px; display: block; }
.dqa-trigger-text { font-size: 12px; line-height: 1; }

.dqa-panel {
  position: fixed; right: 24px; bottom: 24px;
  pointer-events: auto;
  width: 384px; max-width: calc(100vw - 32px);
  height: min(576px, calc(100vh - 80px));
  display: flex; flex-direction: column; overflow: hidden;
  border-radius: 18px;
  border: 1px solid var(--dsw-alias-border-l1, rgba(127,142,163,.35));
  background: var(--dsw-alias-bg-layer-1, #fff);
  box-shadow: 0 20px 52px rgba(0, 0, 0, .24);
  animation: dqa-in .16s ease-out;
}
@keyframes dqa-in { from { opacity: 0; transform: translateY(8px) scale(.98); } to { opacity: 1; transform: none; } }

.dqa-head {
  display: flex; align-items: center; gap: 8px;
  padding: 12px 14px; border-bottom: 1px solid var(--dsw-alias-border-l1, rgba(127,142,163,.2));
  background: var(--dsw-alias-bg-layer-1, #fff);
}
.dqa-title { font-size: 13px; font-weight: 600; letter-spacing: .01em; }
.dqa-sub { font-size: 11px; color: var(--dsw-alias-label-secondary, #8a8f98); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.dqa-grow { flex: 1; min-width: 0; }
.dqa-icon-btn {
  width: 26px; height: 26px; flex: none; padding: 0; display: inline-flex; align-items: center; justify-content: center;
  border: none; border-radius: 8px; cursor: pointer; background: transparent;
  color: var(--dsw-alias-label-secondary, #8a8f98); font-size: 15px; line-height: 1;
}
.dqa-icon-btn:hover { background: var(--dsw-alias-bg-layer-2, rgba(127,142,163,.12)); color: var(--dsw-alias-label-primary, #111); }

.dqa-list {
  flex: 1; overflow-y: auto; overscroll-behavior: contain;
  padding: 14px; display: flex; flex-direction: column; gap: 12px;
}
.dqa-empty { margin: auto 6px; text-align: center; font-size: 12.5px; line-height: 1.8; color: var(--dsw-alias-label-secondary, #8a8f98); }
.dqa-empty b { color: var(--dsw-alias-label-primary, #111); font-weight: 600; }
.dqa-kbd {
  display: inline-block; padding: 0 5px; margin: 0 1px; border-radius: 5px;
  border: 1px solid var(--dsw-alias-border-l1, rgba(127,142,163,.35));
  background: var(--dsw-alias-bg-layer-2, rgba(127,142,163,.1));
  font-size: 11px; line-height: 17px;
}

.dqa-user {
  align-self: flex-end; max-width: 88%;
  padding: 8px 12px; border-radius: 12px 12px 4px 12px;
  background: var(--dsw-alias-bg-layer-2, rgba(127,142,163,.12));
  font-size: 13px; line-height: 1.6; white-space: pre-wrap; word-break: break-word;
}
.dqa-user-quote {
  margin-bottom: 6px; padding: 6px 8px; border-left: 2px solid var(--dsw-alias-brand-primary, #4d6bfe);
  border-radius: 4px; background: var(--dsw-alias-bg-layer-1, rgba(255,255,255,.5));
  font-size: 11.5px; color: var(--dsw-alias-label-secondary, #8a8f98);
  max-height: 76px; overflow: hidden; white-space: pre-wrap;
}
.dqa-bot { align-self: flex-start; max-width: 94%; font-size: 13px; line-height: 1.7; white-space: pre-wrap; word-break: break-word; }
.dqa-bot .dqa-text { min-height: 1em; }
.dqa-bot.dqa-error .dqa-text { color: #c0392b; }
.dqa-tools { display: flex; gap: 6px; margin-top: 6px; opacity: 0; transition: opacity .12s ease; }
.dqa-bot:hover .dqa-tools, .dqa-tools:focus-within { opacity: 1; }
.dqa-mini {
  border: 1px solid var(--dsw-alias-border-l1, rgba(127,142,163,.35)); background: transparent;
  color: var(--dsw-alias-label-secondary, #8a8f98); font-size: 11px; line-height: 18px;
  padding: 0 7px; border-radius: 6px; cursor: pointer;
}
.dqa-mini:hover { color: var(--dsw-alias-label-primary, #111); border-color: var(--dsw-alias-brand-primary, #4d6bfe); }

.dqa-caret::after { content: '▍'; animation: dqa-blink 1s step-end infinite; color: var(--dsw-alias-brand-primary, #4d6bfe); }
@keyframes dqa-blink { 50% { opacity: 0; } }

.dqa-foot { border-top: 1px solid var(--dsw-alias-border-l1, rgba(127,142,163,.2)); padding: 10px 12px; }
.dqa-quote {
  display: flex; align-items: flex-start; gap: 6px; margin-bottom: 8px;
  padding: 6px 8px; border-radius: 8px;
  background: var(--dsw-alias-bg-layer-2, rgba(127,142,163,.12));
  font-size: 11.5px; line-height: 1.5; color: var(--dsw-alias-label-secondary, #8a8f98);
}
.dqa-quote span { flex: 1; max-height: 48px; overflow: hidden; white-space: pre-wrap; }
.dqa-box {
  display: flex; align-items: flex-end; gap: 8px;
  border: 1px solid var(--dsw-alias-border-l1, rgba(127,142,163,.35));
  border-radius: 12px; padding: 6px 8px;
  background: var(--dsw-alias-bg-base, transparent);
}
.dqa-box:focus-within { border-color: var(--dsw-alias-brand-primary, #4d6bfe); }
.dqa-input {
  flex: 1; min-height: 24px; max-height: 120px; resize: none;
  border: none; outline: none; background: transparent;
  color: var(--dsw-alias-label-primary, #111); font: inherit; font-size: 13px; line-height: 1.6;
  padding: 3px 2px;
}
.dqa-send {
  flex: none; width: 30px; height: 30px; padding: 0; border: none; border-radius: 9px; cursor: pointer;
  display: inline-flex; align-items: center; justify-content: center;
  background: var(--dsw-alias-button-primary-fill, var(--dsw-alias-brand-primary, #4d6bfe));
  color: var(--dsw-alias-label-primary-foreground, #fff);
}
.dqa-send:disabled { opacity: .45; cursor: default; }
.dqa-send svg { width: 15px; height: 15px; display: block; }
.dqa-send.dqa-stop { background: var(--dsw-alias-bg-layer-2, rgba(127,142,163,.2)); color: var(--dsw-alias-label-primary, #111); }
.dqa-hint { margin-top: 6px; font-size: 10.5px; color: var(--dsw-alias-label-secondary, #8a8f98); display: flex; gap: 6px; align-items: center; }

.dqa-chip {
  position: fixed; z-index: 901; display: inline-flex; align-items: center; gap: 4px;
  pointer-events: auto;
  height: 26px; padding: 0 9px; border-radius: 13px; cursor: pointer;
  border: 1px solid var(--dsw-alias-border-l1, rgba(127,142,163,.35));
  background: var(--dsw-alias-bg-layer-1, #fff);
  color: var(--dsw-alias-brand-primary, #4d6bfe);
  font-size: 12px; box-shadow: 0 6px 18px rgba(0, 0, 0, .18);
}
.dqa-chip:hover { border-color: var(--dsw-alias-brand-primary, #4d6bfe); }
.dqa-chip svg { width: 13px; height: 13px; }
`

    // ------------------------------------------------------------------ helpers

    function insertStyles() {
      const selector = 'style[data-plugin-css="' + STYLE_KEY + '"]'
      if (document.querySelector(selector) !== null) return () => {}
      const tag = document.createElement('style')
      tag.dataset.plugin = NS
      tag.dataset.pluginCss = STYLE_KEY
      tag.textContent = CSS
      document.head.appendChild(tag)
      return () => {
        tag.remove()
      }
    }

    function askUrl() {
      const base = typeof document !== 'undefined' && document.baseURI ? document.baseURI : location.href
      return new URL(ASK_PATH, base).href
    }

    const IconAsk = (props) =>
      h(
        'svg',
        { viewBox: '0 0 24 24', fill: 'none', 'aria-hidden': 'true', ...props },
        h('path', {
          d: 'M4 11.2C4 6.7 7.6 3.5 12 3.5s8 3.2 8 7.7-3.6 7.7-8 7.7c-.9 0-1.8-.1-2.6-.4L5 20.5l1.2-3.6C4.8 15.6 4 13.5 4 11.2Z',
          stroke: 'currentColor',
          strokeWidth: '1.7',
          strokeLinejoin: 'round',
        }),
        h('path', { d: 'M12 8.2v.05M12 10.6v4.3', stroke: 'currentColor', strokeWidth: '1.8', strokeLinecap: 'round' }),
      )

    const IconSend = () =>
      h(
        'svg',
        { viewBox: '0 0 24 24', fill: 'none', 'aria-hidden': 'true' },
        h('path', { d: 'M4.5 12h13m0 0-5-5m5 5-5 5', stroke: 'currentColor', strokeWidth: '1.9', strokeLinecap: 'round', strokeLinejoin: 'round' }),
      )

    const IconStop = () =>
      h('svg', { viewBox: '0 0 24 24', fill: 'none', 'aria-hidden': 'true' },
        h('rect', { x: '7.5', y: '7.5', width: '9', height: '9', rx: '2', fill: 'currentColor' }))

    const IconSearch = () =>
      h('svg', { viewBox: '0 0 24 24', fill: 'none', 'aria-hidden': 'true' },
        h('circle', { cx: '11', cy: '11', r: '6.2', stroke: 'currentColor', strokeWidth: '1.8' }),
        h('path', { d: 'm16 16 4 4', stroke: 'currentColor', strokeWidth: '1.8', strokeLinecap: 'round' }))

    // ------------------------------------------------------------------ component

    function createView(ctx) {
      const language = () => (String(ctx.locale?.getSnapshot?.().active ?? '').startsWith('en') ? 'en' : 'zh')
      const t = (zh, en) => (language() === 'en' ? en : zh)

      return function QuickAsk() {
        const [open, setOpen] = useState(false)
        const [draft, setDraft] = useState('')
        const [turns, setTurns] = useState([])
        const [quote, setQuote] = useState('')
        const [busy, setBusy] = useState(false)
        const [chip, setChip] = useState(null)
        const listRef = useRef(null)
        const inputRef = useRef(null)
        const abortRef = useRef(null)

        const close = useCallback(() => setOpen(false), [])

        // Alt+Q 开合；Esc 收起
        useEffect(() => {
          const onKey = (event) => {
            if (event.altKey && !event.ctrlKey && !event.metaKey && (event.key === 'q' || event.key === 'Q')) {
              event.preventDefault()
              event.stopPropagation()
              setOpen((value) => !value)
              return
            }
            if (event.key === 'Escape' && open) {
              setOpen(false)
            }
          }
          window.addEventListener('keydown', onKey, true)
          return () => window.removeEventListener('keydown', onKey, true)
        }, [open])

        // 打开面板时聚焦输入框
        useEffect(() => {
          if (open && inputRef.current) inputRef.current.focus()
        }, [open])

        // 新消息滚动到底
        useEffect(() => {
          const node = listRef.current
          if (node) node.scrollTop = node.scrollHeight
        }, [turns, open])

        // 划词后的「问」气泡：只在面板收起时出现
        useEffect(() => {
          if (open) {
            setChip(null)
            return
          }
          const inside = (node) => node instanceof Element && node.closest('input, textarea, [contenteditable="true"], .dqa-root') !== null
          const onUp = () => {
            setTimeout(() => {
              const selection = window.getSelection()
              if (!selection || selection.isCollapsed || selection.rangeCount === 0) {
                setChip(null)
                return
              }
              const text = String(selection).trim()
              if (text.length < 2 || text.length > 5000) {
                setChip(null)
                return
              }
              const anchor = selection.anchorNode
              if (inside(anchor && anchor.nodeType === 1 ? anchor : anchor?.parentElement)) {
                setChip(null)
                return
              }
              const rect = selection.getRangeAt(0).getBoundingClientRect()
              if (rect.width === 0 && rect.height === 0) {
                setChip(null)
                return
              }
              setChip({
                x: Math.max(8, Math.min(rect.right + 8, window.innerWidth - 92)),
                y: Math.max(8, rect.top - 34),
                text,
              })
            }, 0)
          }
          const onDown = (event) => {
            if (event.target instanceof Element && event.target.closest('.dqa-chip')) return
            setChip(null)
          }
          document.addEventListener('mouseup', onUp, true)
          document.addEventListener('mousedown', onDown, true)
          return () => {
            document.removeEventListener('mouseup', onUp, true)
            document.removeEventListener('mousedown', onDown, true)
          }
        }, [open])

        const patchLast = (patch) => {
          setTurns((prev) => {
            if (prev.length === 0) return prev
            const next = prev.slice()
            next[next.length - 1] = { ...next[next.length - 1], ...patch }
            return next
          })
        }

        const send = async () => {
          const question = draft.trim()
          if (question === '' || busy) return
          const quoted = quote
          const history = turns.map((item) => ({ role: item.role, text: item.text }))
          setDraft('')
          setQuote('')
          setBusy(true)
          setTurns((prev) => [
            ...prev,
            { role: 'user', text: question, quote: quoted },
            { role: 'assistant', text: '', streaming: true },
          ])

          const controller = new AbortController()
          abortRef.current = controller
          let answer = ''
          try {
            const response = await fetch(askUrl(), {
              method: 'POST',
              credentials: 'same-origin',
              cache: 'no-store',
              headers: { 'content-type': 'application/json', accept: 'text/event-stream' },
              body: JSON.stringify({ question, quote: quoted, history }),
              signal: controller.signal,
            })
            if (!response.ok) {
              let detail = 'HTTP ' + response.status
              try {
                const data = await response.json()
                if (data && typeof data.message === 'string' && data.message !== '') detail = data.message
              } catch {
                /* 非 JSON 响应，保留状态码 */
              }
              throw new Error(detail)
            }
            if (!response.body) throw new Error(t('宿主没有返回数据流', 'host did not return a stream'))

            const reader = response.body.getReader()
            const decoder = new TextDecoder()
            let buffer = ''
            let failure = null
            for (;;) {
              const { value, done } = await reader.read()
              if (done) break
              buffer += decoder.decode(value, { stream: true })
              let index
              while ((index = buffer.indexOf('\n\n')) >= 0) {
                const raw = buffer.slice(0, index)
                buffer = buffer.slice(index + 2)
                for (const line of raw.split('\n')) {
                  if (!line.startsWith('data:')) continue
                  const text = line.slice(5).trim()
                  if (text === '') continue
                  let event
                  try {
                    event = JSON.parse(text)
                  } catch {
                    continue
                  }
                  if (event.type === 'delta' && typeof event.text === 'string') {
                    answer += event.text
                    patchLast({ text: answer })
                  } else if (event.type === 'error') {
                    failure = typeof event.message === 'string' ? event.message : t('模型调用失败', 'model call failed')
                  }
                }
              }
            }
            if (failure !== null) throw new Error(failure)
            if (answer === '') throw new Error(t('模型没有返回内容', 'the model returned nothing'))
            patchLast({ streaming: false })
          } catch (error) {
            const aborted = error && (error.name === 'AbortError' || controller.signal.aborted)
            const message = aborted ? t('已停止', 'stopped') : String(error && error.message ? error.message : error)
            patchLast({ text: answer, streaming: false, error: message })
          } finally {
            abortRef.current = null
            setBusy(false)
            setQuote('')
          }
        }

        const stop = () => {
          if (abortRef.current) abortRef.current.abort()
        }

        const onInputKey = (event) => {
          if (event.key === 'Enter' && !event.shiftKey && !event.nativeEvent?.isComposing) {
            event.preventDefault()
            void send()
          }
        }

        const copy = async (text) => {
          try {
            await navigator.clipboard.writeText(text)
          } catch {
            /* 剪贴板被拒时保持静默 */
          }
        }

        const clear = () => {
          if (busy) return
          setTurns([])
          setQuote('')
        }

        const openWithQuote = () => {
          if (!chip) return
          setQuote(chip.text)
          setChip(null)
          setOpen(true)
          const selection = window.getSelection()
          if (selection) selection.removeAllRanges()
        }

        const lastModelText = useMemo(() => {
          for (let i = turns.length - 1; i >= 0; i -= 1) {
            if (turns[i].role === 'assistant' && turns[i].text !== '') return turns[i].text
          }
          return ''
        }, [turns])

        const chipView =
          chip && !open
            ? h(
                'button',
                {
                  type: 'button',
                  className: 'dqa-chip',
                  style: { left: chip.x + 'px', top: chip.y + 'px' },
                  onMouseDown: (event) => event.preventDefault(),
                  onClick: openWithQuote,
                  title: t('把选中的文字带进小窗提问', 'Ask about the selected text'),
                },
                h(IconSearch, null),
                h('span', null, t('问', 'Ask')),
              )
            : null

        const trigger = h(
          'button',
          {
            type: 'button',
            className: 'dqa-trigger' + (open ? ' dqa-trigger-on' : ''),
            onClick: () => setOpen((value) => !value),
            title: t('快速问答（Alt+Q）', 'Quick ask (Alt+Q)'),
            'aria-label': t('快速问答', 'Quick ask'),
            'aria-expanded': open ? 'true' : 'false',
          },
          h(IconAsk, null),
          h('span', { className: 'dqa-trigger-text' }, t('问', 'Ask')),
        )

        return h(
          React.Fragment,
          null,
          chipView,
          trigger,
          open
            ? h(
            'div',
            { className: 'dqa-root dqa-panel', role: 'dialog', 'aria-label': t('快速问答', 'Quick ask') },
            h(
              'div',
              { className: 'dqa-head' },
              h('div', { className: 'dqa-grow' },
                h('div', { className: 'dqa-title' }, t('快速问答', 'Quick ask')),
                h('div', { className: 'dqa-sub' }, busy ? t('思考中…', 'Thinking…') : t('旁路提问，不打扰主对话', 'Side channel, the main chat stays untouched')),
              ),
              h(
                'button',
                { type: 'button', className: 'dqa-icon-btn', onClick: clear, disabled: busy, title: t('清空对话', 'Clear') },
                '⌫',
              ),
              h(
                'button',
                { type: 'button', className: 'dqa-icon-btn', onClick: close, title: t('收起（Esc）', 'Close (Esc)') },
                '✕',
              ),
            ),
            h(
              'div',
              { className: 'dqa-list', ref: listRef },
              turns.length === 0
                ? h(
                    'div',
                    { className: 'dqa-empty' },
                    h('div', null, t('随手问一句，答案只在这儿。', 'Ask anything — answers stay right here.')),
                    h('div', { style: { marginTop: '6px' } },
                      t('选中页面里的文字，会冒出「问」；', 'Select text on the page to get an Ask bubble; '),
                      h('br'),
                      t('或者按 ', 'or press '),
                      h('span', { className: 'dqa-kbd' }, 'Alt'),
                      ' + ',
                      h('span', { className: 'dqa-kbd' }, 'Q'),
                      t(' 随时叫出来。', ' any time.'),
                    ),
                  )
                : turns.map((item, index) =>
                    item.role === 'user'
                      ? h(
                          'div',
                          { key: 'u' + index, className: 'dqa-user' },
                          item.quote
                            ? h('div', { className: 'dqa-user-quote' }, item.quote)
                            : null,
                          h('div', null, item.text),
                        )
                      : h(
                          'div',
                          { key: 'a' + index, className: 'dqa-bot' + (item.error ? ' dqa-error' : '') },
                          h('div', {
                            className: 'dqa-text' + (item.streaming ? ' dqa-caret' : ''),
                          }, item.error ? item.error : item.text),
                          item.text && !item.streaming
                            ? h(
                                'div',
                                { className: 'dqa-tools' },
                                h('button', { type: 'button', className: 'dqa-mini', onClick: () => copy(item.text) }, t('复制', 'Copy')),
                              )
                            : null,
                        ),
                  ),
            ),
            h(
              'div',
              { className: 'dqa-foot' },
              quote !== ''
                ? h(
                    'div',
                    { className: 'dqa-quote' },
                    h('span', null, quote.replace(/\s+/g, ' ')),
                    h('button', { type: 'button', className: 'dqa-icon-btn', onClick: () => setQuote(''), title: t('去掉引用', 'Remove quote') }, '✕'),
                  )
                : null,
              h(
                'div',
                { className: 'dqa-box' },
                h('textarea', {
                  ref: inputRef,
                  className: 'dqa-input',
                  rows: 1,
                  value: draft,
                  placeholder: t('问点什么…', 'Ask something…'),
                  onChange: (event) => setDraft(event.target.value),
                  onKeyDown: onInputKey,
                  spellCheck: false,
                }),
                busy
                  ? h('button', { type: 'button', className: 'dqa-send dqa-stop', onClick: stop, title: t('停止', 'Stop') }, h(IconStop, null))
                  : h('button', {
                      type: 'button',
                      className: 'dqa-send',
                      onClick: () => void send(),
                      disabled: draft.trim() === '',
                      title: t('发送（Enter）', 'Send (Enter)'),
                    }, h(IconSend, null)),
              ),
              h(
                'div',
                { className: 'dqa-hint' },
                h('span', null, 'Enter ' + t('发送 · Shift+Enter 换行 · Alt+Q 收起', 'to send · Shift+Enter for a new line · Alt+Q to hide')),
                lastModelText !== '' ? h('span', { className: 'dqa-grow' }) : null,
              ),
            ),
          )
            : null,
        )
      }
    }

    // -------------------------------------------------------------------- entry

    return {
      name: 'dsh-quick-ask-client',
      inject: ['slots'],
      apply(ctx) {
        const report = { stage: 'start', styles: '', places: {}, services: {} }
        try {
          report.stage = 'styles'
          ctx.effect(insertStyles, NS + ': panel styles')
          report.styles = 'ok'
        } catch (error) {
          report.styles = String((error && error.message) || error)
        }

        const View = createView(ctx)
        // 两处都挂：输入框左侧工具条 + 输入框下方 dock，哪个在哪个就能看见。
        for (const place of ['conversation.input.left', 'conversation.composer.dock']) {
          try {
            ctx.slots.inject(place, () =>
              ctx.slots.register({ name: place, id: 'quick-ask:' + place, order: 30 }, View),
            )
            report.places[place] = 'ok'
          } catch (error) {
            report.places[place] = String((error && error.message) || error)
          }
        }

        // 诊断点：客户端模块真的物化了才会打到宿主，用于远程排查。
        try {
          report.stage = 'ping'
          for (const name of ['slots', 'locale', 'connection', 'conversation', 'remote', 'modules', 'loader', 'theme']) {
            try {
              report.services[name] = typeof (typeof ctx.get === 'function' ? ctx.get(name) : ctx[name])
            } catch {
              report.services[name] = 'error'
            }
          }
          report.slotKeys = ctx.slots !== null && typeof ctx.slots === 'object' ? Object.keys(ctx.slots).slice(0, 40) : []
          try {
            const core = ctx.slots && ctx.slots._core
            const probe = ['shell.overlay', 'app.root', 'main', 'sidebar.panellist', 'conversation.composer.dock',
              'conversation.input.left', 'conversation.input.right', 'conversation.input.overlay',
              'conversation.composer.above', 'conversation.composer.below', 'conversation.header',
              'conversation.header.right', 'conversation.chat.node', 'settings.section',
              'plugins.detail.section', 'plugins.row.config']
            report.declared = {}
            for (const key of probe) {
              try {
                report.declared[key] = Boolean(core && typeof core.specDynamic === 'function' && core.specDynamic(key))
              } catch (error) {
                report.declared[key] = 'err:' + String((error && error.message) || error)
              }
            }
            report.slotApi = Object.getOwnPropertyNames(Object.getPrototypeOf(ctx.slots)).filter((n) => n !== 'constructor').slice(0, 60)
          } catch (error) {
            report.declared = 'probe-failed:' + String((error && error.message) || error)
          }
          report.ua = navigator.userAgent
          console.info('[quick-ask] applied', report)
          void fetch(new URL('dsh-quick-ask/ping', document.baseURI), {
            method: 'POST',
            credentials: 'same-origin',
            cache: 'no-store',
            body: JSON.stringify(report),
          }).catch(() => {})
        } catch {
          /* 诊断失败不影响功能 */
        }
      },
    }
  },
})
