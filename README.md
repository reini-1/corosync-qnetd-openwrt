# Corosync QNetd for OpenWrt (ARM64)

> [!NOTE]
>
> This is a fork of [jrparks/corosync-qnetd-openwrt](https://github.com/jrparks/corosync-qnetd-openwrt) that updates
> build system and component versions and fixes Makefiles so build works (e.g. patch libknet configure to really
> disable libknet-sctp).
>
> Ubuntu 26.04 is used as docker build image.
>
> Build for [Gl.Inet MT6000 Flint 2](https://openwrt.org/toh/gl.inet/gl-mt6000) (mediatek/filogic, aarch64_cortex-a53)
> for OpenWrt 24.10.2.
> See Dockerfile & build.sh to modify this for your needed chipset/architecture.

## Overview

Native OpenWrt build of `corosync-qnetd` and all dependencies, targeting aarch64/musl (OpenWrt 24.10.8).

- musl-native, no glibc
- Automatic NSS certificate setup
- Per-IP firewall rules for Proxmox nodes
- Proxmox cluster arbitration ready

---

## Packages

```shell
110K corosync-nss-tools_3.0.4-r1_aarch64_generic.ipk
 61K corosync-qnetd_3.0.4-r1_aarch64_generic.ipk
 49K libknet_1.35-r1_aarch64_generic.ipk
121K libnspr_4.39-r1_aarch64_generic.ipk
1.5M libnss_3.126-r1_aarch64_generic.ipk
 65K libqb_2.0.10-r1_aarch64_generic.ipk
```

`corosync-nss-tools` provides the NSS certificate setup script and the `corosync-qnetd-certutil` wrapper used by Proxmox during `pvecm qdevice setup`.

---

## Build

```bash
# Build the Docker image (first time only)
docker build -t openwrt-corosync .

# Run the build (state is cached in sdk-state/)
bash run-build.sh

# Follow the log
tail -f output/build.log
```

Output `.ipk` files are written to `output/`.

---

## Install

```bash
# Copy packages to router
scp -O output/*.ipk router:/tmp/

ssh root@<router>

# Install all packages
opkg install --nodeps --force-reinstall \
  /tmp/libnspr_*.ipk /tmp/libnss_*.ipk /tmp/libqb_*.ipk \
  /tmp/libknet_*.ipk /tmp/corosync-qnetd_*.ipk \
  /tmp/corosync-nss-tools_*.ipk
```

`--nodeps` skips resolution for system libraries (`libc`, `zlib`) already present on the router. The packages are built as `aarch64_generic` and repacked at build time with the GL.iNet firmware arch string (`aarch64_cortex-a53_neon-vfpv4`) — the binaries are fully compatible.

`--force-reinstall` ensures packages are installed even if a previous version is already present. The `corosync-nss-tools` postinst runs `corosync-qnetd-setup`, which generates NSS integrity check files (`.chk`) via `shlibsign`, initialises the NSS certificate database, and starts the service. The firewall step is skipped at install time — run it manually after (see Post-Install Setup below).
Maybe `--force-overwrite` has also be given if you have something else that installs /usr/lib/libsqlite3.so (need to be fixed...)

---

## Post-Install Setup

Run the setup script with your Proxmox node IPs to create per-IP firewall rules on TCP 5403:

```bash
corosync-qnetd-setup 192.168.0.200 192.168.0.201
```

This creates a single UCI firewall rule (`Allow-QNetd-Proxmox`) with the IPs as `src_ip` on TCP 5403. Re-running the script with a new list replaces the existing rule.

---

## Remove on the router

```bash
rm /tmp/*.ipk
opkg remove corosync-nss-tools corosync-qnetd libknet libqb libnss libnspr
```

## Update

```bash
# Build new ipks
bash run-build.sh

# Copy to router
scp output/*.ipk root@<router>:/tmp/

ssh root@<router>

# Stop the service
/etc/init.d/corosync-qnetd stop

# Reinstall libraries and daemon
opkg install --nodeps --force-reinstall \
  /tmp/libnspr_*.ipk /tmp/libnss_*.ipk /tmp/libqb_*.ipk \
  /tmp/libknet_*.ipk /tmp/corosync-qnetd_*.ipk \
  /tmp/corosync-nss-tools_*.ipk

# Start the service
/etc/init.d/corosync-qnetd enable
/etc/init.d/corosync-qnetd start
```

The NSS certificate database at `/etc/corosync/qnetd/nssdb` is preserved across updates — the setup script only initialises it if it doesn't already exist. Re-run `corosync-qnetd-setup` with your node IPs if firewall rules need to be reapplied.

---

## Usage

```bash
# Start / stop / status
/etc/init.d/corosync-qnetd start
/etc/init.d/corosync-qnetd stop
/etc/init.d/corosync-qnetd status

# Check whats connected
/usr/sbin/corosync-qnetd-tool -s

# Run interactively (foreground, useful for debugging)
corosync-qnetd -f

# Check if the port is listening
netstat -tlnp | grep 5403
```

---

## Proxmox Integration

Install `openssh-sftp-server` and maybe switch from `dropbear` to `openssl-server` on the router first
(required for `pvecm` to SCP files and add new created id_rsa.pub to router root with ssh-copy-id):

```bash
opkg install openssh-sftp-server
```

On all nodes:

`corosync-qdevice` is needed on all proxmox nodes. `pvecm qdevice setup` uses `/usr/sbin/corosync-qdevice-net-certutil`
to manage certificates for corosync. On the router `corosync-qnetd-certutil` is used.

```bash
apt install corosync-qdevice
```

Then on one Proxmox node:

```bash
pvecm qdevice setup <router-ip>
```

Use `--force` if re-running after a previous attempt:

```bash
pvecm qdevice setup <router-ip> --force
```

`pvecm qdevice setup` SSHes into the router, initialises the NSS certificate database, signs the cluster's client certificate via `corosync-qnetd-certutil`, and configures all cluster nodes to connect to qnetd. Once complete, `pvecm status` should show `A,V,NMW` next to each node and `Qdevice` with 1 vote — giving a 2-node cluster a proper tiebreaker.

---

## Notes

- Uses Mozilla NSS for TLS — no OpenSSL dependency
- `corosync-qnetd` source: [corosync/corosync-qdevice](https://github.com/corosync/corosync-qdevice)
- `sdk-state/` is gitignored and holds cached build artifacts between runs
- `output/` is gitignored and holds the built packages.

---

## Future

- LuCI UI
- Cluster auto-registration
- HA monitoring
