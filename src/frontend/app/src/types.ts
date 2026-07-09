export type ProxyMode = 'tproxy' | 'mixed' | 'tun'
export type RoutingMode = 'off' | 'include' | 'exclude'
export type SubscriptionType = 'local' | 'url' | string

export interface SubscriptionState {
  type: SubscriptionType
  url: string
  hours: number
  hwidEnabled?: boolean
  scanLocal?: boolean
}

export interface LanDevice {
  ip: string
  mac: string
  name: string
}

export interface StatusResponse {
  ok: true
  running: boolean
  proxyMode: ProxyMode
  routingMode: RoutingMode
  activeConfig: string
  localConfig: string
  subscriptionConfig: string
  logFile: string
  coreVersion: string
  coreArchitecture: string
  controllerUrl: string
  subscription: SubscriptionState
  routingItems: string[]
  lanDevices: LanDevice[]
}

export interface CommandResponse {
  ok: boolean
  output?: string
  error?: string
  exitCode?: number
}
