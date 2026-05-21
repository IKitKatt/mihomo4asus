# mihomo4asus

Minimal **Mihomo** TProxy runner for **ASUSWRT-Merlin** routers with **Entware** on USB.

## Features

- Router-level Mihomo TProxy routing with DNS redirection for LAN clients.
- HWID subscription headers.
- Remote subscription URL import with automatic refresh.
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
- `Subscription URL`: paste the URL during install; the script downloads and prepares `/opt/root/mihomo/config/sub-config.yaml`.

After a successful subscription import, run:

```sh
mihomo start
```

## Config

For local mode, create or edit:

```sh
nano /opt/root/mihomo/config/config.yaml
```

For subscription mode, the script writes:

```sh
/opt/root/mihomo/config/sub-config.yaml
```

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

`mihomo4asus` can download a user Mihomo config from a subscription URL, send Remnawave HWID headers, and refresh it every N hours while Mihomo is running. The default update interval is 1 hour. If the server returns `profile-update-interval`, that value is saved as the subscription update interval.

Use a subscription URL:

```sh
mihomo subscription set "https://example.com/subscription.yaml"
mihomo subscription update
```

Use the local router config instead:

```sh
mihomo subscription local
```

Show or disable subscription settings:

```sh
mihomo subscription show
mihomo subscription clear
```

If the subscription domain points to the same public IP as the router, router-originated requests can fail because ASUSWRT NAT loopback usually does not apply to the router itself. `mihomo4asus` first tries the URL directly, then scans the router LAN `/24` subnet and retries the same URL with `curl --connect-to` for each local IP while keeping the original URL host for Host/SNI. The first response that looks like a Mihomo YAML config is used.

The downloader sends:

- `x-hwid`
- `x-device-os`
- `x-ver-os`
- `x-device-model`
- `user-agent: mihomo4asus/1.0.0`

The HWID is a SHA-256 hash from firmware version, router model, and a stable first-use date.

When a downloaded config is applied, the script preserves local operational settings required for `mihomo4asus`: `tproxy-port`, UI/controller keys, `dns.listen`, and the full `sniffer` section. During subscription import only, `tun`, `mixed-port`, LAN bind allow-list keys, DNS proxy outbounds, DNS rules, and unsupported fake-ip DNS options are removed from the downloaded config; `find-process-mode` is forced to `off`.

## Routing

`routing.list` stores client IP/CIDR values. `routing.mode` controls how the list is interpreted:

- `include`: only listed clients are routed through Mihomo.
- `exclude`: all LAN clients are routed through Mihomo except listed clients.
- `off`: selective routing is disabled and all LAN clients are routed through Mihomo.

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
