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

- `mihomo` — opens the interactive console menu.
- `mihomo install` — installs or reinstalls the script and Mihomo core.
- `mihomo start` — starts Mihomo, loads required modules, applies routing rules, and registers Merlin hook lines.
- `mihomo stop` — stops Mihomo and removes routing rules.
- `mihomo restart` — restarts Mihomo.
- `mihomo status` — shows current state, architecture, core path, version, and config path.
- `mihomo logs` — follows the Mihomo core log until `Ctrl+C`.
- `mihomo update` — checks the latest Mihomo release, replaces the core if needed, and starts Mihomo again.
- `mihomo subscription` — manages a remote Mihomo YAML subscription config.
- `mihomo setup` — opens interactive include/exclude IP setup.
- `mihomo uninstall` — removes Mihomo core, config folder, runtime files, hook lines, command symlink, and routing rules.

## Subscription Config

`mihomo4asus` can download a user Mihomo config from a subscription URL, send Remnawave HWID headers, and refresh it every N hours while Mihomo is running.

Configure a subscription:

```sh
mihomo subscription set "https://example.com/subscription.yaml" 12
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

If the subscription domain points to the same public IP as the router, router-originated requests can fail because ASUSWRT NAT loopback usually does not apply to the router itself. `mihomo4asus` tries to detect this automatically by reading ASUSWRT port forwarding rules from NVRAM and connecting to the internal target while keeping the original URL host for Host/SNI.

If automatic detection is not possible, keep the public HTTPS URL, but force the subscription host to the internal server IP:

```sh
mihomo subscription resolve 192.168.50.10
```

Disable this override:

```sh
mihomo subscription resolve clear
```

The downloader sends `x-hwid`, `x-device-os`, `x-ver-os`, `x-device-model`, and `user-agent: mihomo4asus/0.0.3`. The HWID is a SHA-256 hash from firmware version, router model, and a stable first-use date.

When a downloaded config is applied, the script preserves local operational settings required for `mihomo4asus`: `tproxy-port`, UI/controller keys, `dns.listen`, and the full `sniffer` section. Other sections from the subscription config replace the local config.

## Include And Exclude Lists

`include.list` stores client IP/CIDR values that should be routed through Mihomo. If `include.list` is empty, all LAN clients are routed through Mihomo by default.

Show included clients:
```sh
mihomo include show
```

Add included clients:
```sh
mihomo include add 192.168.50.20 192.168.50.32/28
```

Delete included clients:
```sh
mihomo include del 192.168.50.20
```

Replace the whole include list:
```sh
mihomo include set 192.168.50.20 192.168.50.30
```

Clear the include list:
```sh
mihomo include clear
```

`exclude.list` stores client IP/CIDR values that should bypass Mihomo. It has priority over `include.list`.

Show excluded clients:
```sh
mihomo exclude show
```

Add excluded clients:
```sh
mihomo exclude add 192.168.50.10 192.168.50.32/28
```

Delete excluded clients:
```sh
mihomo exclude del 192.168.50.10
```

Replace the whole exclude list:
```sh
mihomo exclude set 192.168.50.10
```

Clear the exclude list:
```sh
mihomo exclude clear
```

## Thanks to
- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) for the Mihomo core.
- [Dr4tez/sing-box4asus](https://github.com/Dr4tez/sing-box4asus) for the original ASUSWRT-Merlin script approach.
- [Zephyruso/zashboard](https://github.com/Zephyruso/zashboard) for perfect dashboard
