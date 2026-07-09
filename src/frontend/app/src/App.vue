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
import type { LanDevice, OperationState, ProxyMode, RoutingMode, StatusResponse } from './types'
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
    dashboardUnavailable: 'В активном конфиге не указан external-controller',
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
    select: 'Выбор',
    client: 'Устройство (MAC)',
    ipAddress: 'IP адрес',
    routeDevice: 'Направлять через Mihomo',
    routingTableTitle: 'Устройства LAN для маршрутизации',
    removeDevice: 'Убрать из списка',
    addDelete: 'Добавить / удалить',
    selectKnownDevice: 'Выберите устройство',
    manualAddress: 'IP/CIDR вручную',
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
    clearLog: 'Очистить лог',
    emptyLog: 'Лог пуст.',
    done: 'Готово',
    actionQueued: 'Команда передана роутеру',
    subscriptionPending: 'Импорт подписки не завершился. Проверьте Log.',
    configSaved: 'Конфиг сохранён',
    modeApplied: 'Режим применён',
    modePending: 'Режим не был применён. Проверьте Log.',
    operationPending: 'Операция не завершилась. Проверьте Log.',
    operationFailed: 'Операция завершилась с ошибкой. Проверьте Log.',
    startFailed: 'Mihomo не был запущен. Проверьте Log.',
    stopFailed: 'Mihomo не был остановлен. Проверьте Log.',
    logCleared: 'Лог очищен',
    working: 'Операция выполняется. Статус обновляется автоматически.',
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
    dashboardUnavailable: 'external-controller is not set in the active config',
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
    select: 'Select',
    client: 'Client (MAC)',
    ipAddress: 'IP address',
    routeDevice: 'Route through Mihomo',
    routingTableTitle: 'LAN devices for routing',
    removeDevice: 'Remove from list',
    addDelete: 'Add / Delete',
    selectKnownDevice: 'Select a device',
    manualAddress: 'Manual IP/CIDR',
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
    clearLog: 'Clear log',
    emptyLog: 'Log is empty.',
    done: 'Done',
    actionQueued: 'Command sent to the router',
    subscriptionPending: 'Subscription import did not finish. Check Log.',
    configSaved: 'Config saved',
    modeApplied: 'Mode applied',
    modePending: 'Proxy mode was not applied. Check Log.',
    operationPending: 'The operation did not finish. Check Log.',
    operationFailed: 'The operation failed. Check Log.',
    startFailed: 'Mihomo did not start. Check Log.',
    stopFailed: 'Mihomo did not stop. Check Log.',
    logCleared: 'Log cleared',
    working: 'Operation in progress. Status refreshes automatically.',
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
const currentPage = window.location.pathname.slice(1)
const routerLang = window.MIHOMO_ROUTER_LANGUAGE || routeParams.get('lang') || ''
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
const applyingProxyMode = ref(false)

const actionOperations: Record<string, string> = {
  start: 'core:start',
  stop: 'core:stop',
  restart: 'core:restart',
  'restart-core': 'core:restart',
  reload: 'core:reload',
  'reload-config': 'core:reload',
  'update-core': 'core:update',
  'update-subscription': 'subscription:update',
  'update-app': 'web:update',
  'restart-app': 'web:restart',
  'routing-apply': 'routing:apply',
  'mode-apply': 'mode:apply',
  'clear-log': 'log:clear'
}

const form = reactive({
  proxyMode: 'tproxy' as ProxyMode,
  routingMode: 'exclude' as RoutingMode,
  subscriptionUrl: '',
  subscriptionHours: 1,
  hwidEnabled: true,
  scanLocal: false,
  knownDeviceIp: '',
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
const operationText = computed(() => (busy.value ? t('working') : ''))

const yamlResult = computed(() => {
  if (!configText.value.trim()) return { error: '', warning: '', doc: null }
  const doc = parseDocument(configText.value)
  return {
    error: doc.errors[0]?.message || '',
    warning: doc.warnings[0]?.message || '',
    doc
  }
})

const canOpenDashboard = computed(() => Boolean(status.value?.controllerUrl))

const yamlStateText = computed(() => {
  if (yamlResult.value.error) return `${t('yamlError')}: ${yamlResult.value.error}`
  if (yamlResult.value.warning) return `${t('yamlWarning')}: ${yamlResult.value.warning}`
  return t('yamlOk')
})

const deviceRows = computed(() => {
  const known = new Map<string, LanDevice>()
  for (const device of status.value?.lanDevices || []) {
    if (device.ip) known.set(device.ip, device)
  }
  return selectedIps.value
    .map((ip) => known.get(ip) || { ip, mac: '', name: '' })
    .sort((a, b) => ipSortKey(a.ip).localeCompare(ipSortKey(b.ip)))
})

const availableDevices = computed(() => (status.value?.lanDevices || [])
  .filter((device) => device.ip && !isSelected(device.ip))
  .sort((a, b) => ipSortKey(a.ip).localeCompare(ipSortKey(b.ip))))

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
  toast.text = text.replace(/^\[(SUCCESS|INFO)\]\s*/gim, '').trim()
  toast.error = error
  toast.visible = true
  window.clearTimeout(toastTimer)
  toastTimer = window.setTimeout(() => {
    toast.visible = false
  }, 5200)
}

function fill(next: StatusResponse) {
  status.value = next
  if (!applyingProxyMode.value) form.proxyMode = next.proxyMode || 'tproxy'
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

const delay = (milliseconds: number) => new Promise((resolve) => window.setTimeout(resolve, milliseconds))

async function waitForOperation(name: string, previousId: string, attempts = 40): Promise<OperationState | null> {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    await delay(500)
    const next = await getStatus()
    fill(next)
    const operation = next.operation
    if (operation.name === name && operation.id !== previousId && operation.state !== 'running') {
      return operation
    }
  }
  return null
}

async function runManagedAction(action: string, attempts = 40) {
  const operationName = actionOperations[action]
  if (!operationName) throw new Error(`Unknown action: ${action}`)
  const previousId = status.value?.operation.id || ''
  await runAction(action)
  const operation = await waitForOperation(operationName, previousId, attempts)
  if (!operation) throw new Error(t('operationPending'))
  if (operation.state === 'failed') throw new Error(t('operationFailed'))
}

async function doAction(action: string) {
  await withBusy(action, async () => {
    const attempts = action === 'update-core' || action === 'update-app'
      ? 360
      : action === 'update-subscription'
        ? 180
        : 50
    await runManagedAction(action, attempts)
    await refreshStatus()
    if (action === 'start') {
      if (!status.value?.running) throw new Error(t('startFailed'))
    } else if (action === 'stop') {
      if (status.value?.running) throw new Error(t('stopFailed'))
    } else if (action === 'update-subscription') {
      if (status.value?.activeConfig !== status.value?.subscriptionConfig) throw new Error(t('subscriptionPending'))
      await loadConfig()
      activePage.value = 'config'
      showToast(t('subscriptionSaved'))
      await refreshLog().catch(() => undefined)
      return
    }
    showToast(t('done'))
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
    await runManagedAction(action)
    showToast(saved.output || t('configSaved'))
    await refreshStatus()
    await refreshLog().catch(() => undefined)
  })
}

async function doApplyMode() {
  const selectedMode = form.proxyMode
  applyingProxyMode.value = true
  await withBusy('mode', async () => {
    await saveMode(selectedMode)
    await runManagedAction('mode-apply')
    await refreshStatus()
    if (status.value?.proxyMode !== selectedMode) throw new Error(t('modePending'))
    form.proxyMode = selectedMode
    showToast(t('modeApplied'))
  })
  applyingProxyMode.value = false
}

async function doSaveSubscription() {
  await withBusy('subscription', async () => {
    await saveSubscriptionUrl(form.subscriptionUrl.trim(), Number(form.subscriptionHours) || 1)
    await refreshStatus()
    await runManagedAction('update-subscription', 180)
    await refreshStatus()
    if (status.value?.activeConfig !== status.value?.subscriptionConfig) throw new Error(t('subscriptionPending'))
    await loadConfig()
    activePage.value = 'config'
    showToast(t('subscriptionSaved'))
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
  form.knownDeviceIp = ''
  form.manualIp = ''
}

async function doSaveRouting() {
  await withBusy('routing', async () => {
    await saveRouting(form.routingMode, selectedIps.value.join('\n'))
    await runManagedAction('routing-apply')
    await refreshStatus()
    showToast(t('routingUpdated'))
  })
}

async function clearLog() {
  await withBusy('clear-log', async () => {
    await runManagedAction('clear-log')
    logText.value = ''
    showToast(t('logCleared'))
  })
}

function openDashboard() {
  const url = status.value?.controllerUrl
  if (!url) {
    showToast(t('dashboardUnavailable'), true)
    return
  }
  window.open(url, '_blank', 'noopener,noreferrer')
}

onMounted(async () => {
  const merlinWindow = window as Window & { show_menu?: () => void }
  merlinWindow.show_menu?.()
  await withBusy('init', async () => {
    await refreshStatus()
    await loadConfig()
    await refreshLog().catch(() => undefined)
  })
})
</script>

<template>
  <div id="TopBanner"></div>
  <div id="Loading" class="popup_bg"></div>
  <iframe name="hidden_frame" id="hidden_frame" class="visually-hidden" title="Mihomo action result"></iframe>
  <form id="ruleForm" method="post" action="/start_apply.htm" target="hidden_frame" @submit.prevent>
    <input type="hidden" name="current_page" :value="currentPage" />
    <input type="hidden" name="next_page" :value="currentPage" />
    <input type="hidden" name="group_id" value="" />
    <input type="hidden" name="modified" value="0" />
    <input type="hidden" name="action_mode" value="apply" />
    <input type="hidden" name="action_wait" value="5" />
    <input type="hidden" name="action_script" value="" />
    <table class="content" align="center" cellpadding="0" cellspacing="0">
      <tbody>
        <tr>
          <td width="17">&nbsp;</td>
          <td valign="top" width="202">
            <div id="mainMenu"></div>
            <div id="subMenu"></div>
          </td>
          <td valign="top">
            <div id="tabMenu" class="submenuBlock"></div>
            <table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
              <tbody>
                <tr>
                  <td valign="top">
                    <table id="FormTitle" class="FormTitle" width="760" border="0" cellpadding="4" cellspacing="0">
                      <tbody>
                        <tr bgcolor="#4D595D">
                          <td valign="top">
                            <div id="formfontdesc" class="formfontdesc">
  <main class="shell">
    <header class="topbar">
      <div class="brand">
        <h1>{{ t('appTitle') }}</h1>
        <p>{{ t('subtitle') }}</p>
      </div>
    </header>

    <div v-if="busy" class="operation-status" role="status">{{ operationText }}</div>

    <nav class="tabbar" aria-label="Mihomo menu">
      <button
        v-for="page in pages"
        :key="page.id"
        type="button"
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
          <div class="core-version">
            <span>{{ t('coreVersion') }}</span>
            <strong>{{ status?.coreVersion || 'Mihomo' }}</strong>
            <small>{{ status?.coreArchitecture || 'Linux ARM' }}</small>
          </div>
          <label class="proxy-control">
            <span>{{ t('proxyMode') }}</span>
            <select v-model="form.proxyMode" :disabled="Boolean(busy)">
              <option value="tproxy">TProxy</option>
              <option value="mixed">Mixed</option>
              <option value="tun">Tun</option>
            </select>
          </label>
        </div>
        <div class="inline-actions">
          <button type="button" :disabled="Boolean(busy)" @click="doApplyMode">{{ t('apply') }}</button>
        </div>
      </section>

      <section class="panel span-6">
        <div class="panel-head">
          <h2>{{ t('serviceActions') }}</h2>
        </div>
        <div class="action-grid">
          <button type="button" :disabled="Boolean(busy)" @click="doAction('start')">{{ t('start') }}</button>
          <button type="button" :disabled="Boolean(busy)" @click="doAction('stop')">{{ t('stop') }}</button>
          <button type="button" :disabled="!canOpenDashboard" :title="canOpenDashboard ? '' : t('dashboardUnavailable')" @click="openDashboard">{{ t('coreDashboard') }}</button>
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

        <div class="table-wrap">
          <table class="device-table">
            <caption>{{ t('routingTableTitle') }} ({{ t('maxLimit') }})</caption>
            <thead>
              <tr>
                <th>{{ t('client') }}</th>
                <th>{{ t('ipAddress') }}</th>
                <th>{{ t('routeDevice') }}</th>
                <th>{{ t('addDelete') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr class="device-add-row">
                <td>
                  <select v-model="form.knownDeviceIp" :disabled="Boolean(busy)" @change="form.manualIp = form.knownDeviceIp">
                    <option value="">{{ t('selectKnownDevice') }}</option>
                    <option v-for="device in availableDevices" :key="device.ip" :value="device.ip">
                      {{ device.name || device.mac || device.ip }} ({{ device.ip }})
                    </option>
                  </select>
                </td>
                <td>
                  <input v-model="form.manualIp" :placeholder="t('manualAddress')" @keydown.enter.prevent="addManualIp" />
                </td>
                <td class="route-cell"><span class="route-chip">{{ form.routingMode === 'include' ? t('include') : t('exclude') }}</span></td>
                <td class="device-actions">
                  <button type="button" class="icon-button" :disabled="Boolean(busy)" :title="t('addIp')" :aria-label="t('addIp')" @click="addManualIp">+</button>
                </td>
              </tr>
              <tr v-for="device in deviceRows" :key="device.ip" :class="{ selected: isSelected(device.ip) }">
                <td>
                  <div class="device-client">
                    <span class="device-avatar">{{ (device.name || device.ip).slice(0, 1).toUpperCase() }}</span>
                    <span>
                      <strong>{{ device.name || 'Manual device' }}</strong>
                      <small>{{ device.mac || '-' }}</small>
                    </span>
                  </div>
                </td>
                <td><code>{{ device.ip }}</code></td>
                <td class="route-cell"><span class="route-chip">{{ form.routingMode === 'include' ? t('include') : t('exclude') }}</span></td>
                <td class="device-actions">
                  <button
                    type="button"
                    class="icon-button remove"
                    :disabled="Boolean(busy) || !isSelected(device.ip)"
                    :title="t('removeDevice')"
                    :aria-label="t('removeDevice')"
                    @click="toggleDevice(device.ip, false)"
                  >-</button>
                </td>
              </tr>
              <tr v-if="deviceRows.length === 0">
                <td colspan="4" class="empty-cell">{{ t('noDevices') }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="panel-actions">
          <button type="button" :disabled="Boolean(busy) || selectedCount === 0" @click="selectedIps = []">{{ t('clearSelected') }}</button>
          <button type="button" :disabled="Boolean(busy)" @click="doSaveRouting">{{ t('applyRouting') }}</button>
        </div>
      </section>

      <section class="panel span-6">
        <div class="panel-head">
          <h2>{{ t('subscriptionSettings') }}</h2>
          <button type="button" :disabled="Boolean(busy)" @click="doAction('update-subscription')">{{ t('updateNow') }}</button>
        </div>
        <label class="field">
          <span>{{ t('remnawaveUrl') }}</span>
          <input v-model="form.subscriptionUrl" type="url" placeholder="https://example/sub" />
        </label>
        <label class="field compact">
          <span>{{ t('updateInterval') }}</span>
          <input v-model.number="form.subscriptionHours" type="number" min="1" />
        </label>
        <div class="subscription-options">
          <label class="switch-control">
            <input v-model="form.hwidEnabled" :disabled="Boolean(busy)" type="checkbox" @change="doSaveHwidSupport" />
            <span>{{ t('hwidSupport') }}</span>
          </label>
          <label class="switch-control">
            <input v-model="form.scanLocal" :disabled="Boolean(busy)" type="checkbox" @change="doSaveScanLocal" />
            <span>{{ t('lanFallback') }}</span>
          </label>
        </div>
        <div class="inline-actions">
          <button type="button" :disabled="Boolean(busy)" @click="doSaveSubscription">{{ t('saveUrl') }}</button>
          <button type="button" :disabled="Boolean(busy)" @click="doUseLocal">{{ t('useLocal') }}</button>
        </div>
      </section>

      <section class="panel span-6">
        <div class="panel-head">
          <h2>{{ t('updateSettings') }}</h2>
        </div>
        <div class="action-grid">
          <button type="button" :disabled="Boolean(busy)" @click="doAction('update-core')">{{ t('updateCore') }}</button>
          <button type="button" :disabled="Boolean(busy)" @click="doAction('update-app')">{{ t('updateApp') }}</button>
          <button type="button" :disabled="Boolean(busy)" @click="doAction('restart-app')">{{ t('restartWeb') }}</button>
        </div>
      </section>
    </div>

    <section v-if="activePage === 'config'" class="panel config-panel">
      <div class="panel-head stackable">
        <h2>{{ t('config') }}</h2>
        <div class="inline-actions">
          <input ref="configFileInput" class="visually-hidden" type="file" accept=".yaml,.yml,text/yaml,text/plain" @change="loadConfigFile" />
          <button type="button" :disabled="Boolean(busy)" @click="openConfigFile">{{ t('loadConfig') }}</button>
          <button type="button" :disabled="Boolean(busy) || Boolean(yamlResult.error)" @click="doSaveConfig">{{ t('saveConfig') }}</button>
          <button type="button" :disabled="Boolean(busy) || Boolean(yamlResult.error)" @click="doSaveConfigAndAction('reload-config')">{{ t('saveReloadConfig') }}</button>
          <button type="button" :disabled="Boolean(busy) || Boolean(yamlResult.error)" @click="doSaveConfigAndAction('restart-core')">{{ t('saveRestartCore') }}</button>
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
        <div class="inline-actions">
          <button type="button" :disabled="Boolean(busy)" @click="refreshLog">{{ t('refreshLog') }}</button>
          <button type="button" :disabled="Boolean(busy)" @click="clearLog">{{ t('clearLog') }}</button>
        </div>
      </div>
      <pre>{{ recentLog }}</pre>
    </section>

    <div v-if="toast.visible" class="toast" :class="{ error: toast.error, success: !toast.error }">{{ toast.text }}</div>
  </main>
                            </div>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </td>
                </tr>
              </tbody>
            </table>
          </td>
        </tr>
      </tbody>
    </table>
  </form>
  <div id="footer"></div>
</template>
