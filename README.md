# mihomo4asus

Minimal **Mihomo** TProxy runner for **ASUSWRT-Merlin** routers with **Entware** on USB.

## Features

- Router-level Mihomo TProxy routing with DNS redirection for LAN clients.
- HWID subscription headers.
- HTTP proxy-provider import with automatic node refresh by the core.
- Read-only SSH dashboard with service, routing and subscription sections.
- Separate local and subscription configs.
- Local IP routing control.

## Requirements

- ASUS router running [Asuswrt-Merlin](https://www.asuswrt-merlin.net/). Stock ASUSWRT is not supported.
- Supported router CPU architectures: `aarch64`/`arm64` and `armv7`/`armv7l`.
- USB flash drive or USB storage prepared for Entware.
- [Entware](https://github.com/Entware/Entware) installed on the USB storage.
- [amtm](https://diversion.ch/amtm.html) is recommended for installing Entware on an Asuswrt-Merlin router with a USB flash drive.
- SSH access to the router.

## Install

```sh
mkdir -p /jffs/addons/mihomo && wget -O /jffs/addons/mihomo/mihomo https://raw.githubusercontent.com/IKitKatt/mihomo4asus/main/mihomo && chmod 775 /jffs/addons/mihomo/mihomo && /jffs/addons/mihomo/mihomo install
```

The installer creates the required folders, installs the script to `/jffs/addons/mihomo/mihomo`, creates the `mihomo` command in `/opt/bin/mihomo`, downloads the correct Mihomo core for the router architecture, and installs the core to `/opt/root/mihomo/mihomo`.

During first install, choose the config method:

- `Local config`: put your Mihomo YAML into `/opt/root/mihomo/config/config.yaml`.
- `Proxy-provider` (recommended): paste a Mihomo YAML subscription URL. The script checks it and prepares `/opt/root/mihomo/config/provider-config.yaml`.

After a successful subscription import, run:

```sh
mihomo start
```

## Config

For local mode, create or edit:

```sh
nano /opt/root/mihomo/config/config.yaml
```

For proxy-provider mode, the script writes `/opt/root/mihomo/config/provider-config.yaml`. Edit the local policy in `/opt/root/mihomo/config/provider-template.yaml`, then run `mihomo subscription rebuild` to validate and regenerate it from cache, followed by `mihomo restart` to apply it. The template must not contain a `proxy-providers` block; the script supplies that block. Existing full-config subscriptions continue to use `sub-config.yaml`.

Minimal local config example:

```yaml
mode: rule
tproxy-port: 7894
allow-lan: true
external-controller: 0.0.0.0:9090

dns:
  enable: true
  listen: 0.0.0.0:1053

proxies:
  - name: DIRECT
    type: direct

proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - DIRECT

rules:
  - MATCH,PROXY
```

After editing local config:

```sh
mihomo restart
```

## Commands

- `mihomo` - opens the interactive console menu.
- `mihomo install` - installs or reinstalls the script and Mihomo core.
- `mihomo start` - starts Mihomo and applies routing rules.
- `mihomo stop` - stops Mihomo and removes routing rules.
- `mihomo restart` - restarts Mihomo.
- `mihomo status` - shows current state, paths, version, subscription mode, routing mode, and logs.
- `mihomo logs` - follows the Mihomo core log until `Ctrl+C`.
- `mihomo update` - opens the update menu.
- `mihomo update core` - updates the Mihomo core.
- `mihomo update script` - updates this script from `IKitKatt/mihomo4asus`.
- `mihomo subscription` - configures local or URL config mode.
- `mihomo routing` - manages `routing.list` and include/exclude/off routing mode.
- `mihomo setup` - opens the interactive routing setup.
- `mihomo uninstall` - removes Mihomo core, config folder, runtime files, hook lines, command symlink, and routing rules.

## Subscription Config

### Proxy-provider (recommended)

```sh
mihomo subscription set "https://example.com/subscription.yaml"
mihomo start                 # or restart if already running
```

The initial import requires a Mihomo YAML document with a non-empty top-level `proxies` list. The script downloads it directly with curl, validates the extracted node definitions and the generated config using `mihomo -t`, and stores the original response unchanged in `providers/`. It does not import the remote DNS settings, rules, groups or listeners. URI/base64-only subscription responses are not accepted by the initial importer.

The generated HTTP `proxy-providers.subscription` uses `proxy: DIRECT`, a local cache and the following headers (the same values are used for the initial request):

- `x-hwid`
- `x-device-os`
- `x-ver-os`
- `x-device-model`
- `User-Agent: mihomo4asus/1.0.0`
- `Accept: application/json, text/plain, */*`

Mihomo owns periodic node updates. There is no shell subscription timer or scheduled service restart in this mode. The default interval is one hour; `profile-update-interval` does not override the chosen interval in provider mode.

The first import creates `config/provider-template.yaml` with TProxy on 7894, DNS on 1053 (redir-host, resolvers 1.1.1.1 and 8.8.8.8), and a `PROXY` select group using the provider. `MATCH,PROXY` sends intercepted traffic through that group. Existing local operational settings are copied using the existing preservation helper. Remote routing policy is not copied. Later imports preserve the template. For custom rules, edit the template; for a fully self-managed config, use local mode.

```sh
mihomo subscription hours 6  # change interval using the existing cache (offline)
mihomo subscription rebuild  # regenerate policy from the local template and cache
mihomo restart              # apply the new provider settings
mihomo subscription update  # validate/reimport now; restart if running
mihomo subscription show
mihomo subscription local
```

`set`, `hours` and `rebuild` prepare a config without stopping a running core. Start/restart applies it. The SSH dashboard labels it as the **selected** config, because the running process may still use the previous selection. Manual `update` checks the subscription before restarting. `rebuild` and provider-mode `hours` do not download the subscription or advance the last-import timestamp. A missing cache requires `subscription update`. Previous provider cache files are retained so a running older config keeps a valid cache path.

### Failed imports

No subnet scanning, localhost probing or `--connect-to` fallback is performed, including when the subscription domain points to the router's own external IP. A direct request has a five-second connection limit and a twenty-second total limit, with at most three HTTP redirects. On failure, interactive installation/import displays:

```text
?? ??????? ????????????? ????????.
?????????? ??? ???????? (Y/N) [N]:
```

`Y` continues with the previous configuration (local mode on a fresh installation); it does not enable the failed subscription or fabricate a working config. `N`, empty input and EOF cancel the operation. A command-line `subscription set` failure returns nonzero without prompting, so automated calls cannot block on input. The existing config and subscription settings are retained on failed downloads or validation.

### Existing full-config subscriptions

Existing `TYPE=url` settings remain supported and are not silently converted to providers. The legacy method can also be selected explicitly:

```sh
mihomo subscription full "https://example.com/full-config.yaml"
mihomo subscription update
```

That method retains the previous YAML sanitization, local operational-key preservation and shell refresh timer. Prefer `subscription set` for new subscriptions. `mihomo subscription clear` selects local mode again.

### SSH console

Run `mihomo` for the sectioned dashboard and numeric menu. `mihomo status` prints the same read-only snapshot plus details. Rendering does not install hooks, migrate files or make remote requests. Firewall status reports chain hooks, not an end-to-end connectivity test. Colors are enabled only on a terminal; ASCII separators also work without Unicode support. EOF exits menus. No ASUS web interface files are changed.

## Routing

`routing.list` stores client IP/CIDR values. `routing.mode` controls how the list is interpreted:

- `include`: only listed clients are routed through Mihomo. An empty list intercepts nobody, including DNS.
- `exclude`: all LAN clients are routed through Mihomo except listed clients.
- `off`: selective routing is disabled and all LAN clients are routed through Mihomo.

The `include`/`exclude` decision is applied only to traffic entering from the LAN interface. Before TProxy, the firewall protects the router's actual local addresses (using the kernel `addrtype LOCAL` match when available, with an explicit-address fallback), the directly connected LAN networks, and traffic entering through ASUS firmware VPN interfaces (`tun+`, `tap+`, and `wg+`). RFC1918 supernets are not bypassed globally, so private corporate networks can still reach Mihomo rules when they are selected by the client policy. If a LAN client is simultaneously covered by a firmware full-tunnel VPN and by Mihomo, select one owner for that client in the routing policy to avoid competing paths.

Show routing state:

```sh
mihomo routing show
```

Switch mode:

```sh
mihomo routing mode include
mihomo routing mode exclude
mihomo routing mode off
```

Edit list:

```sh
mihomo routing add 192.168.50.20 192.168.50.32/28
mihomo routing del 192.168.50.20
mihomo routing set 192.168.50.20 192.168.50.30
mihomo routing clear
```

Reapply routing rules:

```sh
mihomo routing restart
```

## Uninstall

Run:

```sh
mihomo uninstall
```

This stops Mihomo, removes routing rules, removes boot hook lines, deletes `/opt/root/mihomo`, removes the `/opt/bin/mihomo` command symlink, and removes the script from `/jffs/addons/mihomo/mihomo`.

## Thanks To

- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) for the Mihomo core.
- [Dr4tez/sing-box4asus](https://github.com/Dr4tez/sing-box4asus) for the original ASUSWRT-Merlin script approach.
- [Zephyruso/zashboard](https://github.com/Zephyruso/zashboard) for the dashboard.

## Service and firewall behavior

`start` and `stop` preserve the core log. When the size guard reaches its threshold, it copies the current log to `mihomo.log.1` before truncating the active file, retaining one previous snapshot.

Firewall application requires a running core and checks rule/route creation results. Concurrent `apply-rules` calls are rejected using `run/firewall.lock`. On failure the script attempts to remove partial rules, clears its applied-state marker, and returns an error. If application fails during `start`, the newly started service is stopped. Cleanup errors can still require inspection of the router's actual firewall; a successful process check alone does not prove end-to-end connectivity. `stop` continues to remove autostart hooks as in the previous version.

## Tests

Run isolated regressions with `python3 tests/test_shell.py` on a machine with `sh`. They use temporary files and network/router-command stubs. Set `TEST_SHELL` to select another shell, such as BusyBox ash through a wrapper. Optionally set `TEST_CORE` to an absolute Mihomo binary path to validate generated configs with the real core in `-t` mode and run an HTTP-provider smoke test. That smoke test starts a temporary server on 127.0.0.1 and a core process without router listeners, verifies headers, refresh and raw cache preservation, then stops both. No router configuration is touched.
