# mihomo4asus

Minimal Mihomo runner for ASUSWRT-Merlin routers with Entware on USB.

Thanks to:

- [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) for the Mihomo core.
- [Dr4tez/sing-box4asus](https://github.com/Dr4tez/sing-box4asus) for the original ASUSWRT-Merlin script approach.

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
mkdir -p /opt/root/mihomo/config
nano /opt/root/mihomo/config/config.yaml
```

Copy an existing config file into place:

```sh
cp /tmp/config.yaml /opt/root/mihomo/config/config.yaml
```

After editing the config, restart Mihomo:

```sh
mihomo restart
```

## Commands

Open the interactive console menu:

```sh
mihomo
```

Install or reinstall the script and Mihomo core:

```sh
mihomo install
```

Start Mihomo, load kernel modules, apply iptables/ip rule/ip route rules, and register Merlin hook lines:

```sh
mihomo start
```

Stop Mihomo and remove routing rules:

```sh
mihomo stop
```

Restart Mihomo:

```sh
mihomo restart
```

Show current state, architecture, core path, version, and config path:

```sh
mihomo status
```

Check the latest Mihomo release. If a newer core exists, stop Mihomo, replace the core, and start it again:

```sh
mihomo update
```

Open interactive include/exclude IP setup:

```sh
mihomo setup
```

Remove Mihomo core, config folder, runtime files, hook lines, command symlink, and routing rules:

```sh
mihomo uninstall
```

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
