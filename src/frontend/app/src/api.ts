import type { CommandResponse, RoutingMode, StatusResponse } from './types'

declare global {
  interface Window {
    MIHOMO_API_ORIGIN?: string
    MIHOMO_ROUTER_LANGUAGE?: string
  }
}

const apiOrigin = window.MIHOMO_API_ORIGIN?.replace(/\/$/, '') || ''

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

export async function getStatus(): Promise<StatusResponse> {
  const response = await fetch(endpoint('status'))
  return parseJson<StatusResponse>(response)
}

export async function getConfig(): Promise<string> {
  const response = await fetch(endpoint('config'))
  if (!response.ok) throw new Error(await response.text())
  return response.text()
}

export async function getLog(): Promise<string> {
  const response = await fetch(endpoint('log'))
  if (!response.ok) throw new Error(await response.text())
  return response.text()
}

export async function runAction(name: string): Promise<CommandResponse> {
  const response = await fetch(endpoint('action', { name }), { method: 'POST' })
  return parseJson<CommandResponse>(response)
}

export async function saveConfig(config: string): Promise<CommandResponse> {
  const response = await fetch(endpoint('save-config'), {
    method: 'POST',
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    body: config
  })
  return parseJson<CommandResponse>(response)
}

export async function saveMode(value: string): Promise<CommandResponse> {
  const response = await fetch(endpoint('mode', { value }), { method: 'POST' })
  return parseJson<CommandResponse>(response)
}

export async function saveRouting(mode: RoutingMode, items: string): Promise<CommandResponse> {
  const response = await fetch(endpoint('routing', { mode }), {
    method: 'POST',
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    body: items
  })
  return parseJson<CommandResponse>(response)
}

export async function saveSubscriptionUrl(url: string, hours: number): Promise<CommandResponse> {
  const response = await fetch(endpoint('subscription', { type: 'url', hours }), {
    method: 'POST',
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    body: url
  })
  return parseJson<CommandResponse>(response)
}

export async function useLocalSubscription(): Promise<CommandResponse> {
  const response = await fetch(endpoint('subscription', { type: 'local' }), { method: 'POST' })
  return parseJson<CommandResponse>(response)
}

export async function saveSubscriptionMeta(field: 'hwidEnabled' | 'scanLocal', value: string): Promise<CommandResponse> {
  const response = await fetch(endpoint('subscription-meta', { field }), {
    method: 'POST',
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    body: value
  })
  return parseJson<CommandResponse>(response)
}
