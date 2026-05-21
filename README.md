# mihomo4asus

Minimal **Mihomo** runner for **ASUSWRT-Merlin** routers with **Entware** on USB.

## Install

```sh
mkdir -p /jffs/addons/mihomo && wget -O /jffs/addons/mihomo/mihomo https://raw.githubusercontent.com/IKitKatt/mihomo4asus/main/mihomo && chmod 775 /jffs/addons/mihomo/mihomo && /jffs/addons/mihomo/mihomo install
```

The installer creates the required folders, installs the script to `/jffs/addons/mihomo/mihomo`, creates the `mihomo` command in `/opt/bin/mihomo`, downloads the correct Mihomo core for the router architecture, and installs the core to `/opt/root/mihomo/mihomo`.

## Config

Main config path:

```sh
/opt/root/mihomo/config/config.yaml
```

This must be a normal Mihomo YAML config. It should contain at least:

- general mode settings, for example `mode: rule`;
- `tproxy-port`;
- `dns` section if DNS redirection is used;
- `proxies`;
- `proxy-groups`;
- `rules`.

Minimal config example:

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

Create or edit the config directly on the router:

```sh
nano /opt/root/mihomo/config/config.yaml
```

After editing the config, restart Mihomo:
```sh
mihomo restart
```

## Commands

- `mihomo` вЂ” opens the interactive console menu.
- `mihomo install` вЂ” installs or reinstalls the script and Mihomo core.
- `mihomo start` вЂ” starts Mihomo, loads required modules, applies routing rules, and registers Merlin hook lines.
- `mihomo stop` вЂ” stops Mihomo and removes routing rules.
- `mihomo restart` вЂ” restarts Mihomo.
- `mihomo status` вЂ” shows current state, architecture, core path, version, and config path.
- `mihomo logs` вЂ” follows the Mihomo core log until `Ctrl+C`.
- `mihomo update` - opens the update menu.
- `mihomo update core` - checks the latest Mihomo release, replaces the core if needed, and starts Mihomo again.
- `mihomo update script` - updates this script from `IKitKatt/mihomo4asus`.
- `mihomo subscription` - selects local router config or a remote Mihomo YAML subscription URL.
- `mihomo routing` - manages `routing.list` and include/exclude/off routing mode.
- `mihomo setup` - opens the interactive routing setup.
- `mihomo uninstall` вЂ” removes Mihomo core, config folder, runtime files, hook lines, command symlink, and routing rules.

## Subscription Config

`mihomo4asus` can download a user Mihomo config from a subscription URL, send Remnawave HWID headers, and refresh it every N hours while Mihomo is running. The default update interval is 1 hour. If the server returns `profile-update-interval`, that value is saved as the subscription update interval.

Configure a subscription:

```sh
mihomo subscription set "https://example.com/subscription.yaml"
```

Use the local router config instead of a subscription URL:

```sh
mihomo subscription local
```

Update immediately:

```sh
mihomo subscription update
```

Show or disable subscription settings:

```sh
mihomo subscription show
mihomo subscription clear
```

If the subscription domain points to the same public IP as the router, router-originated requests can fail because ASUSWRT NAT loopback usually does not apply to the router itself. `mihomo4asus` first tries the URL directly, then scans the router LAN `/24` subnet and retries the same URL with `curl --connect-to` for each local IP while keeping the original URL host for Host/SNI. The first response that looks like a Mihomo YAML config is used.

The downloader sends `x-hwid`, `x-device-os`, `x-ver-os`, `x-device-model`, and `user-agent: mihomo4asus/0.0.3`. The HWID is a SHA-256 hash from firmware version, router model, and a stable first-use date.

When a downloaded config is applied, the script preserves local operational settings required for `mihomo4asus`: `tproxy-port`, UI/controller keys, `dns.listen`, and the full `sniffer` section. During subscription import only, `tun`, `mixed-port`, LAN bind allow-list keys, DNS proxy outbounds, DNS rules, and unsupported fake-ip DNS options are removed from the downloaded config; `find-process-mode` is forced to `off`.

Local config is stored in `/opt/root/mihomo/config/config.yaml`. Subscription URL config is stored separately in `/opt/root/mihomo/config/sub-config.yaml` and is used only when subscription method is `url`. Runtime settings, routing lists, and subscription state are stored in `/opt/root/mihomo/state`.

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

## Thanks to
- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) for the Mihomo core.
- [Dr4tez/sing-box4asus](https://github.com/Dr4tez/sing-box4asus) for the original ASUSWRT-Merlin script approach.
- [Zephyruso/zashboard](https://github.com/Zephyruso/zashboard) for perfect dashboard
