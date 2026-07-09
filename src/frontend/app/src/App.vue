<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { parseDocument } from 'yaml'
import {
  getConfig,
  getLog,
  getStatus,
  runAction,
  saveConfig,
  saveMode,
  saveRouting,
  saveSubscriptionMeta,
  saveSubscriptionUrl,
  useLocalSubscription
} from './api'
import type { LanDevice, ProxyMode, RoutingMode, StatusResponse } from './types'
import YamlEditor from './components/YamlEditor.vue'

const messages = {
  ru: {
    appTitle: 'Mihomo',
    subtitle: 'ASUSWRT-Merlin / Entware',
    running: 'запущено',
    stopped: 'остановлено',
    status: 'Статус',
    proxyMode: 'Режим прокси',
    apply: 'Применить',
    hwidSupport: 'Поддержка HWID',
    main: 'Главное',
    config: 'Конфиг',
    logs: 'Лог',
    start: 'Запустить',
    stop: 'Остановить',
    coreDashboard: 'Панель ядра',
    dashboardUnavailable: 'В config.yaml не указан external-controller',
    serviceActions: 'Сервис',
    coreVersion: 'Версия ядра',
    saveConfig: 'Сохранить',
    saveReloadConfig: 'Сохранить и перезагрузить конфиг',
    saveRestartCore: 'Сохранить и перезапустить ядро',
    loadConfig: 'Загрузить файл',
    configFileLoaded: 'YAML-файл загружен',
    configFileTooLarge: 'Размер YAML-файла превышает 4 МБ',
    configFileReadError: 'Не удалось прочитать YAML-файл',
    yamlOk: 'YAML синтаксис корректен',
    yamlError: 'Ошибка YAML',
    yamlWarning: 'Предупреждение YAML',
    include: 'Include',
    exclude: 'Exclude',
    includeHint: 'Только выбранные IP будут направляться через Mihomo.',
    excludeHint: 'Выбранные IP будут обходить Mihomo.',
    devices: 'Устройства',
    selected: 'выбрано',
    ipAddress: 'IP адрес',
    hostname: 'Имя',
    macAddress: 'MAC',
    addIp: 'Добавить IP',
    manualIp: 'IP/CIDR вручную',
    clearSelected: 'Очистить выбор',
    applyRouting: 'Применить маршрутизацию',
    maxLimit: 'Лимит: 128',
    noDevices: 'DHCP-устройства не найдены. Добавьте IP вручную.',
    routingSettings: 'LAN устройства',
    remnawaveUrl: 'Remnawave URL',
    subscriptionSettings: 'Подписка',
    updateInterval: 'Интервал, часы',
    saveUrl: 'Сохранить URL',
    useLocal: 'Локальный конфиг',
    updateNow: 'Обновить сейчас',
    lanFallback: 'Проверять известные адреса в LAN',
    updateSettings: 'Обновления',
    updateCore: 'Обновить ядро',
    updateApp: 'Обновить приложение',
    restartWeb: 'Перезапустить Web',
    refreshLog: 'Обновить лог',
    emptyLog: 'Лог пуст.',
    done: 'Готово',
    configSaved: 'Конфиг сохранён',
    modeApplied: 'Режим применён',
    subscriptionSaved: 'Подписка сохранена',
    localEnabled: 'Локальный конфиг включён',
    routingUpdated: 'Routing обновлён',
    hwidUpdated: 'HWID Support обновлён',
    scanUpdated: 'Проверка адресов LAN обновлена',
    invalidIp: 'Введите корректный IPv4 или CIDR',
    duplicateIp: 'Этот IP уже выбран',
    limitReached: 'Лимит 128 устройств достигнут'
  },
  en: {
    appTitle: 'Mihomo',
    subtitle: 'ASUSWRT-Merlin / Entware',
    running: 'running',
    stopped: 'stopped',
    status: 'Status',
    proxyMode: 'Proxy Mode',
    apply: 'Apply',
    hwidSupport: 'HWID Support',
    main: 'Main',
    config: 'Config',
    logs: 'Log',
    start: 'Start',
    stop: 'Stop',
    coreDashboard: 'Core Dashboard',
    dashboardUnavailable: 'external-controller is not set in config.yaml',
    serviceActions: 'Service',
    coreVersion: 'Core version',
    saveConfig: 'Save',
    saveReloadConfig: 'Save & Reload Config',
    saveRestartCore: 'Save & Restart Core',
    loadConfig: 'Load file',
    configFileLoaded: 'YAML file loaded',
    configFileTooLarge: 'YAML file is larger than 4 MB',
    configFileReadError: 'Unable to read the YAML file',
    yamlOk: 'YAML syntax is valid',
    yamlError: 'YAML error',
    yamlWarning: 'YAML warning',
    include: 'Include',
    exclude: 'Exclude',
    includeHint: 'Only selected IP addresses will use Mihomo.',
    excludeHint: 'Selected IP addresses will bypass Mihomo.',
    devices: 'Devices',
    selected: 'selected',
    ipAddress: 'IP address',
    hostname: 'Name',
    macAddress: 'MAC',
    addIp: 'Add IP',
    manualIp: 'Manual IP/CIDR',
    clearSelected: 'Clear selected',
    applyRouting: 'Apply routing',
    maxLimit: 'Max Limit: 128',
    noDevices: 'No DHCP devices found. Add an IP manually.',
    routingSettings: 'LAN devices',
    remnawaveUrl: 'Remnawave URL',
    subscriptionSettings: 'Subscription',
    updateInterval: 'Interval, hours',
    saveUrl: 'Save URL',
    useLocal: 'Use local config',
    updateNow: 'Update now',
    lanFallback: 'Check known LAN addresses',
    updateSettings: 'Updates',
    updateCore: 'Update core',
    updateApp: 'Update app',
    restartWeb: 'Restart Web',
    refreshLog: 'Refresh log',
    emptyLog: 'Log is empty.',
    done: 'Done',
    configSaved: 'Config saved',
    modeApplied: 'Mode applied',
    subscriptionSaved: 'Subscription saved',
    localEnabled: 'Local config enabled',
    routingUpdated: 'Routing updated',
    hwidUpdated: 'HWID Support updated',
    scanUpdated: 'LAN address recovery updated',
    invalidIp: 'Enter a valid IPv4 or CIDR',
    duplicateIp: 'This IP is already selected',
    limitReached: '128 device limit reached'
  }
} as const

type Page = 'main' | 'config' | 'logs'

const routeParams = new URLSearchParams(window.location.search)
const routerLang = routeParams.get('lang') || ''
const locale: keyof typeof messages = /^en/i.test(routerLang) ? 'en' : 'ru'
const t = (key: keyof typeof messages.en) => messages[locale][key]

const status = ref<StatusResponse | null>(null)
const configText = ref('')
const logText = ref('')
const busy = ref('')
const configFileInput = ref<HTMLInputElement | null>(null)
const initialPage = routeParams.get('page')
const activePage = ref<Page>(
  initialPage === 'config' ||
  initialPage === 'logs'
    ? initialPage
    : 'main'
)
const selectedIps = ref<string[]>([])
const toast = reactive({ text: '', error: false, visible: false })
let toastTimer: number | undefined

const form = reactive({
  proxyMode: 'tproxy' as ProxyMode,
  routingMode: 'exclude' as RoutingMode,
  subscriptionUrl: '',
  subscriptionHours: 1,
  hwidEnabled: true,
  scanLocal: false,
  manualIp: ''
})

const pages: Array<{ id: Page; label: keyof typeof messages.en }> = [
  { id: 'main', label: 'main' },
  { id: 'config', label: 'config' },
  { id: 'logs', label: 'logs' }
]

const runningClass = computed(() => (status.value?.running ? 'running' : 'stopped'))
const runningText = computed(() => (status.value?.running ? t('running') : t('stopped')))
const recentLog = computed(() => logText.value.split(/\r?\n/).slice(-180).join('\n') || t('emptyLog'))
const selectedCount = computed(() => selectedIps.value.length)
const routingHint = computed(() => (form.routingMode === 'include' ? t('includeHint') : t('excludeHint')))

const yamlResult = computed(() => {
  if (!configText.value.trim()) return { error: '', warning: '', doc: null }
  const doc = parseDocument(configText.value)
  return {
    error: doc.errors[0]?.message || '',
    warning: doc.warnings[0]?.message || '',
    doc
  }
})

const hasExternalController = computed(() => {
  if (yamlResult.value.error || !yamlResult.value.doc) return false
  const value = yamlResult.value.doc.get('external-controller', true)
  return typeof value === 'string' && value.trim().length > 0
})

const canOpenDashboard = computed(() => Boolean(status.value?.controllerUrl && hasExternalController.value))

const yamlStateText = computed(() => {
  if (yamlResult.value.error) return `${t('yamlError')}: ${yamlResult.value.error}`
  if (yamlResult.value.warning) return `${t('yamlWarning')}: ${yamlResult.value.warning}`
  return t('yamlOk')
})

const deviceRows = computed(() => {
  const rows = new Map<string, LanDevice>()
  for (const device of status.value?.lanDevices || []) {
    if (device.ip) rows.set(device.ip, device)
  }
  for (const ip of selectedIps.value) {
    if (!rows.has(ip)) rows.set(ip, { ip, mac: '', name: 'manual' })
  }
  return Array.from(rows.values()).sort((a, b) => ipSortKey(a.ip).localeCompare(ipSortKey(b.ip)))
})

function ipSortKey(ip: string) {
  return ip.replace(/\d+/g, (part) => part.padStart(3, '0'))
}

function normalizeIp(value: string) {
  return value.trim().replace(/\s+/g, '')
}

function validIpOrCidr(value: string) {
  return /^(25[0-5]|2[0-4]\d|1?\d?\d)(\.(25[0-5]|2[0-4]\d|1?\d?\d)){3}(\/(3[0-2]|[12]?\d))?$/.test(value)
}

function showToast(text: string, error = false) {
  toast.text = text
  toast.error = error
  toast.visible = true
  window.clearTimeout(toastTimer)
  toastTimer = window.setTimeout(() => {
    toast.visible = false
  }, 5200)
}

function fill(next: StatusResponse) {
  status.value = next
  form.proxyMode = next.proxyMode || 'tproxy'
  form.routingMode = next.routingMode === 'include' ? 'include' : 'exclude'
  selectedIps.value = Array.from(new Set(next.routingItems || []))
  form.subscriptionUrl = next.subscription?.url || ''
  form.subscriptionHours = next.subscription?.hours || 1
  form.hwidEnabled = next.subscription?.hwidEnabled !== false
  form.scanLocal = Boolean(next.subscription?.scanLocal)
}

async function withBusy(label: string, task: () => Promise<void>) {
  busy.value = label
  try {
    await task()
  } catch (error) {
    showToast(error instanceof Error ? error.message : String(error), true)
  } finally {
    busy.value = ''
  }
}

async function refreshStatus() {
  fill(await getStatus())
}

async function loadConfig() {
  configText.value = await getConfig()
}

function openConfigFile() {
  configFileInput.value?.click()
}

async function loadConfigFile(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return

  if (file.size > 4 * 1024 * 1024) {
    showToast(t('configFileTooLarge'), true)
    return
  }

  await withBusy('load-file', async () => {
    try {
      configText.value = await file.text()
      showToast(t('configFileLoaded'))
    } catch {
      showToast(t('configFileReadError'), true)
    }
  })
}

async function refreshLog() {
  logText.value = await getLog()
}

async function doAction(action: string) {
  await withBusy(action, async () => {
    const result = await runAction(action)
    showToast(result.output || t('done'))
    await refreshStatus()
    if (action !== 'stop') await refreshLog().catch(() => undefined)
  })
}

async function doSaveConfig() {
  if (yamlResult.value.error) {
    showToast(yamlStateText.value, true)
    return
  }
  await withBusy('save-config', async () => {
    const result = await saveConfig(configText.value)
    showToast(result.output || t('configSaved'))
    await refreshStatus()
  })
}

async function doSaveConfigAndAction(action: 'reload-config' | 'restart-core') {
  if (yamlResult.value.error) {
    showToast(yamlStateText.value, true)
    return
  }
  await withBusy(action, async () => {
    const saved = await saveConfig(configText.value)
    const applied = await runAction(action)
    showToast(applied.output || saved.output || t('configSaved'))
    await refreshStatus()
    await refreshLog().catch(() => undefined)
  })
}

async function doApplyMode() {
  await withBusy('mode', async () => {
    const result = await saveMode(form.proxyMode)
    showToast(result.output || t('modeApplied'))
    await refreshStatus()
  })
}

async function doSaveSubscription() {
  await withBusy('subscription', async () => {
    const result = await saveSubscriptionUrl(form.subscriptionUrl.trim(), Number(form.subscriptionHours) || 1)
    showToast(result.output || t('subscriptionSaved'))
    await refreshStatus()
  })
}

async function doUseLocal() {
  await withBusy('local-subscription', async () => {
    const result = await useLocalSubscription()
    showToast(result.output || t('localEnabled'))
    await refreshStatus()
  })
}

async function doSaveHwidSupport() {
  await withBusy('hwid-support', async () => {
    await saveSubscriptionMeta('hwidEnabled', form.hwidEnabled ? 'true' : 'false')
    showToast(t('hwidUpdated'))
    await refreshStatus()
  })
}

async function doSaveScanLocal() {
  await withBusy('scan-local', async () => {
    await saveSubscriptionMeta('scanLocal', form.scanLocal ? 'true' : 'false')
    showToast(t('scanUpdated'))
    await refreshStatus()
  })
}

function isSelected(ip: string) {
  return selectedIps.value.includes(ip)
}

function toggleDevice(ip: string, enabled: boolean) {
  const clean = normalizeIp(ip)
  if (!clean) return
  if (enabled) {
    if (isSelected(clean)) return
    if (selectedIps.value.length >= 128) {
      showToast(t('limitReached'), true)
      return
    }
    selectedIps.value = [...selectedIps.value, clean]
    return
  }
  selectedIps.value = selectedIps.value.filter((item) => item !== clean)
}

function onDeviceChange(ip: string, event: Event) {
  toggleDevice(ip, (event.target as HTMLInputElement).checked)
}

function addManualIp() {
  const clean = normalizeIp(form.manualIp)
  if (!validIpOrCidr(clean)) {
    showToast(t('invalidIp'), true)
    return
  }
  if (isSelected(clean)) {
    showToast(t('duplicateIp'), true)
    return
  }
  if (selectedIps.value.length >= 128) {
    showToast(t('limitReached'), true)
    return
  }
  selectedIps.value = [...selectedIps.value, clean]
  form.manualIp = ''
}

async function doSaveRouting() {
  await withBusy('routing', async () => {
    const result = await saveRouting(form.routingMode, selectedIps.value.join('\n'))
    showToast(result.output || t('routingUpdated'))
    await refreshStatus()
  })
}

function openDashboard() {
  if (!hasExternalController.value) {
    showToast(t('dashboardUnavailable'), true)
    return
  }
  if (status.value?.controllerUrl) {
    window.open(status.value.controllerUrl, '_blank', 'noopener')
  } else {
    showToast(t('dashboardUnavailable'), true)
  }
}

onMounted(async () => {
  await withBusy('init', async () => {
    await refreshStatus()
    await loadConfig()
    await refreshLog().catch(() => undefined)
  })
})
</script>

<template>
  <main class="shell">
    <header class="topbar">
      <div class="brand">
        <h1>{{ t('appTitle') }}</h1>
        <p>{{ t('subtitle') }}</p>
      </div>
    </header>

    <nav class="tabbar" aria-label="Mihomo menu">
      <button
        v-for="page in pages"
        :key="page.id"
        :class="{ active: activePage === page.id }"
        @click="activePage = page.id"
      >
        {{ t(page.label) }}
      </button>
    </nav>

    <div v-if="activePage === 'main'" class="main-grid">
      <section class="panel span-6">
        <div class="panel-head">
          <h2>{{ t('status') }}</h2>
          <span class="badge" :class="runningClass">{{ runningText }}</span>
        </div>
        <div class="status-facts">
          <div>
            <span>{{ t('coreVersion') }}</span>
            <strong>{{ status?.coreVersion || 'unknown' }}</strong>
          </div>
          <label class="field inline-field">
            <span>{{ t('proxyMode') }}</span>
            <select v-model="form.proxyMode" :disabled="Boolean(busy)">
              <option value="tproxy">TProxy</option>
              <option value="mixed">Mixed</option>
              <option value="tun">Tun</option>
            </select>
          </label>
        </div>
        <div class="inline-actions">
          <button :disabled="Boolean(busy)" @click="doApplyMode">{{ t('apply') }}</button>
        </div>
      </section>

      <section class="panel span-6">
        <div class="panel-head">
          <h2>{{ t('serviceActions') }}</h2>
        </div>
        <div class="action-grid">
          <button :disabled="Boolean(busy)" @click="doAction('start')">{{ t('start') }}</button>
          <button :disabled="Boolean(busy)" @click="doAction('stop')">{{ t('stop') }}</button>
          <button :disabled="!canOpenDashboard" :title="canOpenDashboard ? '' : t('dashboardUnavailable')" @click="openDashboard">{{ t('coreDashboard') }}</button>
        </div>
      </section>

      <section class="panel span-12">
        <div class="panel-head stackable">
          <div>
            <h2>{{ t('routingSettings') }}</h2>
            <p class="hint">{{ routingHint }}</p>
          </div>
          <div class="count-badge">{{ selectedCount }} / 128 {{ t('selected') }}</div>
        </div>

        <div class="segmented two" role="group" aria-label="Routing mode">
          <label :class="{ active: form.routingMode === 'include' }">
            <input v-model="form.routingMode" type="radio" value="include" />
            <span>{{ t('include') }}</span>
          </label>
          <label :class="{ active: form.routingMode === 'exclude' }">
            <input v-model="form.routingMode" type="radio" value="exclude" />
            <span>{{ t('exclude') }}</span>
          </label>
        </div>

        <div class="manual-row">
          <label class="field inline-field">
            <span>{{ t('manualIp') }}</span>
            <input v-model="form.manualIp" placeholder="192.168.50.20" @keydown.enter.prevent="addManualIp" />
          </label>
          <button :disabled="Boolean(busy)" @click="addManualIp">{{ t('addIp') }}</button>
          <button :disabled="Boolean(busy) || selectedCount === 0" @click="selectedIps = []">{{ t('clearSelected') }}</button>
        </div>

        <div class="table-wrap">
          <table class="device-table">
            <thead>
              <tr>
                <th></th>
                <th>{{ t('hostname') }}</th>
                <th>{{ t('ipAddress') }}</th>
                <th>{{ t('macAddress') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="device in deviceRows" :key="device.ip">
                <td>
                  <input
                    :checked="isSelected(device.ip)"
                    type="checkbox"
                    @change="onDeviceChange(device.ip, $event)"
                  />
                </td>
                <td>{{ device.name || '-' }}</td>
                <td><code>{{ device.ip }}</code></td>
                <td>{{ device.mac || '-' }}</td>
              </tr>
              <tr v-if="deviceRows.length === 0">
                <td colspan="4" class="empty-cell">{{ t('noDevices') }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="panel-actions">
          <span class="hint">{{ t('maxLimit') }}</span>
          <button :disabled="Boolean(busy)" @click="doSaveRouting">{{ t('applyRouting') }}</button>
        </div>
      </section>

      <section class="panel span-6">
        <div class="panel-head">
          <h2>{{ t('subscriptionSettings') }}</h2>
          <button :disabled="Boolean(busy)" @click="doAction('update-subscription')">{{ t('updateNow') }}</button>
        </div>
        <label class="field">
          <span>{{ t('remnawaveUrl') }}</span>
          <input v-model="form.subscriptionUrl" type="url" placeholder="https://example/sub" />
        </label>
        <label class="field compact">
          <span>{{ t('updateInterval') }}</span>
          <input v-model.number="form.subscriptionHours" type="number" min="1" />
        </label>
        <label class="switch-control wide">
          <input v-model="form.hwidEnabled" :disabled="Boolean(busy)" type="checkbox" @change="doSaveHwidSupport" />
          <span>{{ t('hwidSupport') }}</span>
        </label>
        <label class="switch-control wide">
          <input v-model="form.scanLocal" :disabled="Boolean(busy)" type="checkbox" @change="doSaveScanLocal" />
          <span>{{ t('lanFallback') }}</span>
        </label>
        <div class="inline-actions">
          <button :disabled="Boolean(busy)" @click="doSaveSubscription">{{ t('saveUrl') }}</button>
          <button :disabled="Boolean(busy)" @click="doUseLocal">{{ t('useLocal') }}</button>
        </div>
      </section>

      <section class="panel span-6">
        <div class="panel-head">
          <h2>{{ t('updateSettings') }}</h2>
        </div>
        <div class="action-grid">
          <button :disabled="Boolean(busy)" @click="doAction('update-core')">{{ t('updateCore') }}</button>
          <button :disabled="Boolean(busy)" @click="doAction('update-app')">{{ t('updateApp') }}</button>
          <button :disabled="Boolean(busy)" @click="doAction('restart-app')">{{ t('restartWeb') }}</button>
        </div>
      </section>
    </div>

    <section v-if="activePage === 'config'" class="panel">
      <div class="panel-head stackable">
        <h2>{{ t('config') }}</h2>
        <div class="inline-actions">
          <input ref="configFileInput" class="visually-hidden" type="file" accept=".yaml,.yml,text/yaml,text/plain" @change="loadConfigFile" />
          <button :disabled="Boolean(busy)" @click="openConfigFile">{{ t('loadConfig') }}</button>
          <button :disabled="Boolean(busy) || Boolean(yamlResult.error)" @click="doSaveConfig">{{ t('saveConfig') }}</button>
          <button :disabled="Boolean(busy) || Boolean(yamlResult.error)" @click="doSaveConfigAndAction('reload-config')">{{ t('saveReloadConfig') }}</button>
          <button :disabled="Boolean(busy) || Boolean(yamlResult.error)" @click="doSaveConfigAndAction('restart-core')">{{ t('saveRestartCore') }}</button>
        </div>
      </div>
      <YamlEditor v-model="configText" />
      <div class="syntax-status" :class="{ error: yamlResult.error, warning: yamlResult.warning && !yamlResult.error }">
        {{ yamlStateText }}
      </div>
    </section>

    <section v-if="activePage === 'logs'" class="panel logs-panel">
      <div class="panel-head">
        <h2>{{ t('logs') }}</h2>
        <button :disabled="Boolean(busy)" @click="refreshLog">{{ t('refreshLog') }}</button>
      </div>
      <pre>{{ recentLog }}</pre>
    </section>

    <div v-if="toast.visible" class="toast" :class="{ error: toast.error }">{{ toast.text }}</div>
  </main>
</template>
