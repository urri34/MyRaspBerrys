#!/bin/bash
set -eu
set -o pipefail

export DEBIAN_FRONTEND=noninteractive

# === CONFIG XARXA ===
IFACE="eth0"
STATIC_IP="192.168.1.19/24"
GATEWAY="192.168.1.1"
DNS="192.168.1.1"

RUNNING_KERNEL="$(uname -r)"

echo "== Rasp1 ajustos: minim + eth fixa + neteja /boot + 1 initramfs =="
echo "Kernel en execució: ${RUNNING_KERNEL}"
echo

echo ">> 0) APT update"
apt update -y

# Accelerador opcional (si hi és)
apt install -y eatmydata >/dev/null 2>&1 || true
EAT=""
command -v eatmydata >/dev/null 2>&1 && EAT="eatmydata"

# --------------------
# Xarxa
# --------------------
echo ">> 1) Ethernet IP fixa amb systemd-networkd"
mkdir -p /etc/systemd/network
cat > "/etc/systemd/network/10-${IFACE}.network" <<EOF
[Match]
Name=${IFACE}

[Network]
Address=${STATIC_IP}
Gateway=${GATEWAY}
DNS=${DNS}
EOF

systemctl enable --now systemd-networkd || true

echo ">> 2) resolv.conf estàtic (gestionant immutable)"
command -v chattr >/dev/null 2>&1 && chattr -i /etc/resolv.conf 2>/dev/null || true
rm -f /etc/resolv.conf || true
echo "nameserver ${DNS}" > /etc/resolv.conf
command -v chattr >/dev/null 2>&1 && chattr +i /etc/resolv.conf 2>/dev/null || true

# --------------------
# Xarxa legacy / WiFi
# --------------------
echo ">> 3) Fora NetworkManager / WiFi"
systemctl disable --now NetworkManager wpa_supplicant 2>/dev/null || true

$EAT apt purge -y \
  network-manager network-manager-l10n libnm0 \
  netplan.io netplan-generator python3-netplan libnetplan1 \
  wpasupplicant iw wireless-tools \
  dhcpcd-base isc-dhcp-client isc-dhcp-common || true

# Firmwares WiFi
$EAT apt purge -y \
  firmware-brcm80211 firmware-atheros firmware-mediatek firmware-libertas || true

# --------------------
# Impressió / Desktop / Audio
# --------------------
echo ">> 4) Fora CUPS/desktop/audio"
$EAT apt purge -y \
  cups* ipp-usb pi-printer-support sane-* \
  "rpd-*" \
  dbus-x11 xauth \
  pipewire* wireplumber* alsa-utils \
  plymouth plymouth-themes || true

# --------------------
# Python
# --------------------
echo ">> 5) Fora Python COMPLET"
$EAT apt purge -y \
  python-is-python3 python3 python3-minimal python3-venv \
  python3-pip python3-setuptools python3-wheel \
  "python3-*" "libpython*" || true

# --------------------
# 🟨 KERNEL HEADERS (AQUÍ EL QUE DEMANAVES)
# --------------------
echo ">> 6) Fora TOTS els linux-headers (segur: NO toca el kernel)"
$EAT apt purge -y \
  "linux-headers-*" \
  "linux-kbuild-*" || true

# --------------------
# Kernels innecessaris
# --------------------
echo ">> 7) Fora kernels NO v6"
$EAT apt purge -y \
  linux-image-*rpi-v7* \
  linux-image-*rpi-v8* \
  "linux-image-rpi-v8:arm64" || true

# --------------------
# Serveis que no calen
# --------------------
echo ">> 8) Fora serveis no essencials"
systemctl disable --now rpcbind avahi-daemon bluetooth ModemManager 2>/dev/null || true
$EAT apt purge -y rpcbind nfs-common avahi-daemon bluez modemmanager || true

# --------------------
# Cleanup
# --------------------
echo ">> 9) Autoremove final"
$EAT apt autoremove -y --purge
apt autoclean -y

# --------------------
# Neteja /boot
# --------------------
echo ">> 10) Neteja /boot (només kernel en execució)"
shopt -s nullglob
for f in /boot/{initrd.img,vmlinuz,config,System.map}-*; do
  case "$f" in
    *"${RUNNING_KERNEL}"* ) ;;
    * ) rm -f "$f" ;;
  esac
done
rm -f /boot/*.new /boot/*.dpkg-bak 2>/dev/null || true

# --------------------
# Initramfs únic
# --------------------
echo ">> 11) update-initramfs (únic)"
update-initramfs -u -k "${RUNNING_KERNEL}" || true

echo
echo "== FET =="
echo "Kernel actiu: ${RUNNING_KERNEL}"
echo "Xarxa: ${IFACE} ${STATIC_IP}"
echo
echo "Recomanat: sudo reboot"