import type { CommandResponse, RoutingMode, StatusResponse } from './types'

declare global {
  interface Window {
    MIHOMO_API_ORIGIN?: string
    MIHOMO_ROUTER_LANGUAGE?: string
  }
}

const apiOrigin = window.MIHOMO_API_ORIGIN?.replace(/\/$/, '') || ''
const requestTimeoutMs = 45_000
const merlinActions: Record<string, string> = {
  start: 'mihomo_core_start',
  stop: 'mihomo_core_stop',
  restart: 'mihomo_core_restart',
  'restart-core': 'mihomo_core_restart',
  reload: 'mihomo_core_reload',
  'reload-config': 'mihomo_core_reload',
  'update-core': 'mihomo_core_update',
  'update-subscription': 'mihomo_subscription_update',
  'update-app': 'mihomo_web_update',
  'restart-app': 'mihomo_web_restart',
  'routing-apply': 'mihomo_routing_apply',
  'mode-apply': 'mihomo_mode_apply',
  'clear-log': 'mihomo_log_clear'
}

const endpoint = (op: string, params: Record<string, string | number | boolean> = {}) => {
  const query = new URLSearchParams({ op })
  Object.entries(params).forEach(([key, value]) => query.set(key, String(value)))
  return `${apiOrigin}/cgi-bin/api?${query.toString()}`
}

async function parseJson<T>(response: Response): Promise<T> {
  const text = await response.text()
  let data: CommandResponse
  try {
    data = JSON.parse(text) as CommandResponse
  } catch {
    throw new Error(text || response.statusText)
  }
  if (!data.ok) {
    throw new Error(data.error || data.output || 'Request failed')
  }
  return data as T
}

async function request(url: string, init: RequestInit = {}, timeoutMs = requestTimeoutMs): Promise<Response> {
  const controller = new AbortController()
  const timeout = window.setTimeout(() => controller.abort(), timeoutMs)
  try {
    return await fetch(url, { ...init, signal: controller.signal })
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new Error('Request timed out')
    }
    throw error
  } finally {
    window.clearTimeout(timeout)
  }
}

export async function getStatus(): Promise<StatusResponse> {
  const response = await request(endpoint('status'))
  return parseJson<StatusResponse>(response)
}

export async function getConfig(): Promise<string> {
  const response = await request(endpoint('config'))
  if (!response.ok) throw new Error(await response.text())
  return response.text()
}

export async function getLog(): Promise<string> {
  const response = await request(endpoint('log'))
  if (!response.ok) throw new Error(await response.text())
  return response.text()
}

export async function runAction(name: string): Promise<CommandResponse> {
  const action = merlinActions[name]
  if (!action) throw new Error(`Unknown action: ${name}`)

  await new Promise<void>((resolve) => {
    const form = document.createElement('form')
    const cleanup = () => {
      form.remove()
      resolve()
    }

    form.method = 'post'
    form.action = '/start_apply.htm'
    form.target = 'hidden_frame'
    for (const [name, value] of Object.entries({
      action_mode: 'apply',
      action_script: action,
      action_wait: '',
      modified: '0'
    })) {
      const input = document.createElement('input')
      input.type = 'hidden'
      input.name = name
      input.value = value
      form.append(input)
    }

    document.body.append(form)
    form.submit()
    window.setTimeout(cleanup, 250)
  })

  return { ok: true }
}

export async function saveConfig(config: string): Promise<CommandResponse> {
  const response = await request(endpoint('save-config'), {
    method: 'POST',
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    body: config
  })
  return parseJson<CommandResponse>(response)
}

export async function saveMode(value: string): Promise<CommandResponse> {
  const response = await request(endpoint('mode', { value }), { method: 'POST' })
  return parseJson<CommandResponse>(response)
}

export async function saveRouting(mode: RoutingMode, items: string): Promise<CommandResponse> {
  const response = await request(endpoint('routing', { mode }), {
    method: 'POST',
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    body: items
  })
  return parseJson<CommandResponse>(response)
}

export async function saveSubscriptionUrl(url: string, hours: number): Promise<CommandResponse> {
  const response = await request(endpoint('subscription', { type: 'url', hours }), {
    method: 'POST',
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    body: url
  })
  return parseJson<CommandResponse>(response)
}

export async function useLocalSubscription(): Promise<CommandResponse> {
  const response = await request(endpoint('subscription', { type: 'local' }), { method: 'POST' })
  return parseJson<CommandResponse>(response)
}

export async function saveSubscriptionMeta(field: 'hwidEnabled' | 'scanLocal', value: string): Promise<CommandResponse> {
  const response = await request(endpoint('subscription-meta', { field }), {
    method: 'POST',
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    body: value
  })
  return parseJson<CommandResponse>(response)
}
