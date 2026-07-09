# mihomo4asus

Minimal **Mihomo** TProxy runner for **ASUSWRT-Merlin** routers with **Entware** on USB.

## Features

- Router-level Mihomo TProxy routing with DNS redirection for LAN clients.
- Entware-backed web application and CGI backend for router-local management.
- HWID subscription headers.
- Remote subscription URL import with automatic refresh.
- Fast subscription fetch path: direct HTTP/1.1 request first, then optional recovery through addresses already known to the router.
- Separate local and subscription configs.
- Local IP routing control.
- WAN/LAN/WIFI interface bypass list for interfaces that must not enter Mihomo routing.
- Proxy mode switcher: TProxy is implemented for router routing; Mixed and Tun can start the core without TProxy rules for configs that provide their own listeners/TUN settings.

## Requirements

- ASUS router running [Asuswrt-Merlin](https://www.asuswrt-merlin.net/). Stock ASUSWRT is not supported.
- Supported router CPU architectures: `aarch64`/`arm64` and `armv7`/`armv7l`.
- USB flash drive or USB storage prepared for Entware.
- [Entware](https://github.com/Entware/Entware) installed on the USB storage.
- [amtm](https://diversion.ch/amtm.html) is recommended for installing Entware on an Asuswrt-Merlin router with a USB flash drive.
- SSH access to the router.

## Install

Copy this single command to the router SSH console:

```sh
wget -q -O /tmp/mihomo4asus-install.sh https://raw.githubusercontent.com/IKitKatt/mihomo4asus/web/install-app.sh && sh /tmp/mihomo4asus-install.sh
```

The full installer copies the CLI, backend modules, Merlin addon page, Vue web frontend and CGI backend to `/jffs/addons/mihomo`, installs `curl` and `lighttpd` through Entware `/opt` when needed, starts the web service on port `5581`, and mounts a `Mihomo` tab at the end of the Merlin VPN menu when Addons API is available.

The installer creates the required folders, installs the entrypoint and backend modules to `/jffs/addons/mihomo`, creates the `mihomo` command in `/opt/bin/mihomo`, downloads the correct Mihomo core for the router architecture, and installs the core to `/opt/root/mihomo/mihomo`.

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
- `mihomo reload` - reloads the active config through Mihomo external controller and reapplies routing rules.
- `mihomo status` - shows current state, paths, version, subscription mode, routing mode, and logs.
- `mihomo logs` - follows the Mihomo core log until `Ctrl+C`.
- `mihomo update` - opens the update menu.
- `mihomo update core` - updates the Mihomo core.
- `mihomo update script` - updates this script from `IKitKatt/mihomo4asus`.
- `mihomo subscription` - configures local or URL config mode.
- `mihomo routing` - manages `routing.list` and include/exclude/off routing mode.
- `mihomo interfaces` - manages interfaces that bypass TProxy and DNS redirect rules.
- `mihomo mode` - shows or switches proxy mode: `tproxy`, `mixed`, or `tun`.
- `mihomo setup` - opens the interactive routing setup.
- `mihomo uninstall` - removes Mihomo core, config folder, runtime files, hook lines, command symlink, and routing rules.

## Web Application

After full install, open:

```sh
http://<router-lan-ip>:5581/
```

The Merlin Addons API page also appears as `VPN -> Mihomo` on supported firmware. The web backend is a small CGI API served by Entware `lighttpd` using `src/frontend/server.conf`; it does not require Node.js or Python on the router. The web frontend source is in `src/frontend/app` and is built with Vue 3, TypeScript and Vite into static files under `src/frontend/www`.

The web interface can:

- edit and save the raw local Mihomo config;
- reload the active config through `external-controller` or restart the whole core;
- update Mihomo core and the mihomo4asus application;
- switch `tproxy`, `mixed`, and `tun` mode;
- set include/exclude/off routing for local devices;
- exclude interfaces such as `br0`, `eth0`, or `wl0.1`;
- configure and refresh Remnawave subscriptions;
- configure subscription `x-hwid`, `user-agent`, and optional local LAN address recovery;
- open the internal Mihomo dashboard from the configured `external-controller`.

For config reload, the active YAML must expose an HTTP `external-controller`, for example `external-controller: 0.0.0.0:9090`. If a `secret` is configured, it is sent as a Bearer token.

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

If the subscription domain points to the same public IP as the router, router-originated requests can fail because ASUSWRT NAT loopback usually does not apply to the router itself. `mihomo4asus` first tries a direct HTTP/1.1 request with bounded timeouts. With `scan-local on`, it can then retry the same URL through `127.0.0.1` and a small, bounded set of LAN addresses already known from DHCP leases, static assignments, and the neighbour table. `curl --connect-to` keeps the original URL host for Host and SNI. The first response that looks like a Mihomo YAML config is used; the whole `/24` is never scanned.

The downloader sends:

- `x-hwid`
- `x-device-os`
- `x-ver-os`
- `x-device-model`
- `user-agent: mihomo4asus/1.0.0`

The HWID is a SHA-256 hash from firmware version, router model, and a stable first-use date. It is filtered to Remnawave-compatible characters (`A-Z`, `a-z`, `0-9`, `=`, `-`) and kept within the documented 10-64 character range.

Show the exact outgoing subscription headers:

```sh
mihomo subscription headers
```

Override or reset HWID:

```sh
mihomo subscription hwid UE42LJXu4DbiCaBv
mihomo subscription hwid auto
```

Override user-agent:

```sh
mihomo subscription user-agent "mihomo4asus/1.0.0"
```

Enable local address recovery only when it is actually needed:

```sh
mihomo subscription scan-local on
mihomo subscription scan-local off
```

When a downloaded config is applied, the script preserves local operational settings required for `mihomo4asus`: `tproxy-port`, UI/controller keys, `dns.listen`, and the full `sniffer` section. During subscription import only, `tun`, `mixed-port`, LAN bind allow-list keys, DNS proxy outbounds, DNS rules, and unsupported fake-ip DNS options are removed from the downloaded config; `find-process-mode` is forced to `off`.

## Project Structure

Runtime backend code is decomposed into modules:

```text
src/cli/mihomo                  CLI entrypoint
src/examples/                   YAML and routing-list examples
src/backend/_globals.sh
src/backend/core.sh
src/backend/subscription.sh
src/backend/routing.sh
src/backend/service.sh
src/backend/install.sh
src/backend/cli.sh
src/backend/main.sh
```

`src/cli/mihomo` is a thin entrypoint that sources these modules and dispatches commands. This mirrors the source/build separation used by ASUSWRT Merlin XrayUI while keeping a POSIX shell runtime suitable for Entware routers.

Web source and router static output are separate:

```text
src/frontend/app/             Vue 3 + TypeScript + Vite source
src/frontend/www/             static files served on the router
src/frontend/www/cgi-bin/api
```

Build the web UI locally:

```sh
cd src/frontend/app
npm install
npm run build
```

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

## Interface Bypass

Use this when traffic entering a specific WAN/LAN/WIFI interface must bypass Mihomo rules:

```sh
mihomo interfaces show
mihomo interfaces set wl0.1 eth0
mihomo interfaces add br0
mihomo interfaces del wl0.1
mihomo interfaces clear
```

Interface bypass is applied before device include/exclude routing and before DNS redirect rules.

## Proxy Modes

```sh
mihomo mode show
mihomo mode set tproxy
mihomo mode set mixed
mihomo mode set tun
```

`tproxy` is the primary router-wide mode and applies iptables/ip rule routing. `mixed` and `tun` start the Mihomo core without TProxy routing rules; the active config must define the required `mixed-port` or `tun` section itself.

## Uninstall

Run:

```sh
sh uninstall-app.sh
```

This stops the web service, removes the Merlin addon page, stops Mihomo, removes routing rules, removes boot hook lines, deletes `/opt/root/mihomo`, removes the `/opt/bin/mihomo` command symlink, and removes `/jffs/addons/mihomo`.

CLI-only uninstall is still available:

```sh
mihomo uninstall
```

## Thanks To

- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) for the Mihomo core.
- [Dr4tez/sing-box4asus](https://github.com/Dr4tez/sing-box4asus) for the original ASUSWRT-Merlin script approach.
- [Zephyruso/zashboard](https://github.com/Zephyruso/zashboard) for the dashboard.
