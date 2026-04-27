#!/bin/bash
# =============================================================
# Script de neteja per Raspberry Pi Zero 2W
# Elimina GUI, Bluetooth, WiFi, multimedia, eines de dev, etc.
# Xarxa: IP fixa via systemd-networkd (sense NetworkManager)
# Python: neteja total + reinstal·lació mínima per paho-mqtt
# Kernels: elimina kernels i headers antics (manté l'actual)
# =============================================================

set -e

# Trampa per mostrar en quin pas ha fallat
trap 'echo "ERROR al pas anterior. Sortint."; exit 1' ERR

echo "=== Inici de neteja ==="

# =============================================================
# PAS 0: Configurar IP fixa amb systemd-networkd ABANS de res
# =============================================================
echo "[0/12] Configurant IP fixa via systemd-networkd..."

systemctl enable systemd-networkd

cat > /etc/systemd/network/10-eth0.network << 'EOF'
[Match]
Name=eth0

[Network]
Address=192.168.1.18/24
Gateway=192.168.1.1
DNS=192.168.1.1

[Link]
RequiredForOnline=yes
EOF

# DNS sense systemd-resolved: fitxer estàtic
echo "nameserver 192.168.1.1" > /etc/resolv.conf
# Fer-lo immutable perquè NM/dhcpcd no el sobreescriguin
chattr +i /etc/resolv.conf

systemctl start systemd-networkd

echo "    IP fixa configurada: 192.168.1.18/24 gw 192.168.1.1"

# =============================================================
# PAS 1: Eliminar NetworkManager i dhcpcd
# =============================================================
echo "[1/12] Eliminant NetworkManager i dhcpcd..."
systemctl stop NetworkManager 2>/dev/null || true
systemctl disable NetworkManager 2>/dev/null || true

# Treure l'atribut immutable temporalment per si NM el toca durant la purga
chattr -i /etc/resolv.conf 2>/dev/null || true

apt-get purge -y \
  network-manager \
  network-manager-gnome \
  dhcpcd dhcpcd5 \
  udhcpc \
  dnsmasq-base 2>/dev/null || true

# Tornar a posar-lo immutable
echo "nameserver 192.168.1.1" > /etc/resolv.conf
chattr +i /etc/resolv.conf

# =============================================================
# PAS 2: Neteja de paquets rc (residuals)
# =============================================================
echo "[2/12] Purgant paquets residuals (rc)..."
dpkg -l | awk '/^rc/{print $2}' | xargs -r apt-get purge -y || true

# =============================================================
# PAS 3: Entorn gràfic complet
# =============================================================
echo "[3/12] Eliminant entorn gràfic..."
apt-get purge -y \
  lightdm lightdm-gtk-greeter pi-greeter \
  labwc openbox xcompmgr \
  lxpanel-pi lxsession lxsession-logout lxtask lxterminal lxpolkit \
  wf-panel-pi \
  xserver-xorg xserver-xorg-core xserver-xorg-input-all \
  xserver-xorg-video-all xserver-xorg-video-fbdev \
  xserver-xorg-video-amdgpu xserver-xorg-video-ati \
  xserver-xorg-video-radeon xserver-xorg-video-nouveau \
  xwayland x11-common x11-xkb-utils x11-xserver-utils \
  xfonts-encodings xfonts-utils \
  libx11-6 libx11-data libx11-xcb1 libxau6 libxcb1 \
  libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 \
  libxi6 libxinerama1 libxrandr2 libxrender1 libxss1 \
  libxt6t64 libxtst6 libxv1 libxxf86vm1 2>/dev/null || true

# =============================================================
# PAS 4: Bluetooth
# =============================================================
echo "[4/12] Eliminant Bluetooth..."
systemctl disable bluetooth 2>/dev/null || true
apt-get purge -y \
  bluez bluez-firmware \
  mpris-proxy 2>/dev/null || true
dpkg -l | awk '/^ii.*libbluetooth/{print $2}' | xargs -r apt-get purge -y 2>/dev/null || true

# =============================================================
# PAS 5: WiFi / wireless
# =============================================================
echo "[5/12] Eliminant WiFi..."
systemctl disable wpa_supplicant 2>/dev/null || true
apt-get purge -y \
  wireless-tools wpasupplicant \
  libiw30t64 2>/dev/null || true

# =============================================================
# PAS 6: Impressores i escàners
# =============================================================
echo "[6/12] Eliminant impressores/escàners..."
apt-get purge -y \
  cups cups-browsed cups-daemon cups-filters cups-core-drivers \
  cups-pk-helper ipp-usb hplip hplip-data \
  sane-airscan sane-utils \
  printer-driver-escpr printer-driver-postscript-hp \
  system-config-printer-common system-config-printer-udev \
  libsane1 libsane-common libsane-hpaio \
  libcups2t64 libcupsfilters1t64 libcupsimage2t64 2>/dev/null || true

# =============================================================
# PAS 7: Multimèdia
# =============================================================
echo "[7/12] Eliminant multimèdia..."
apt-get purge -y \
  vlc vlc-bin vlc-data vlc-l10n \
  ffmpeg \
  pipewire pipewire-bin pipewire-pulse \
  wireplumber \
  timgm6mb-soundfont pocketsphinx-en-us \
  mkvtoolnix 2>/dev/null || true
dpkg -l | awk '/^ii.*vlc-plugin/{print $2}'   | xargs -r apt-get purge -y 2>/dev/null || true
dpkg -l | awk '/^ii.*gstreamer1\.0/{print $2}'| xargs -r apt-get purge -y 2>/dev/null || true
dpkg -l | awk '/^ii.*libgstreamer/{print $2}' | xargs -r apt-get purge -y 2>/dev/null || true
dpkg -l | awk '/^ii.*libpulse/{print $2}'     | xargs -r apt-get purge -y 2>/dev/null || true
dpkg -l | awk '/^ii.*libpipewire/{print $2}'  | xargs -r apt-get purge -y 2>/dev/null || true
dpkg -l | awk '/^ii.*libspa-/{print $2}'      | xargs -r apt-get purge -y 2>/dev/null || true

# =============================================================
# PAS 8: Navegadors web
# =============================================================
echo "[8/12] Eliminant navegadors web..."
apt-get purge -y \
  chromium chromium-common chromium-l10n chromium-sandbox \
  firefox \
  rpi-chromium-mods rpi-firefox-mods \
  lynx lynx-common 2>/dev/null || true

# =============================================================
# PAS 9: Eines de compilació i desenvolupament
# =============================================================
echo "[9/12] Eliminant eines de desenvolupament..."
apt-get purge -y \
  build-essential \
  gdb openocd fio flashrom \
  meson ninja-build make \
  pahole strace \
  libasan8 libubsan1 2>/dev/null || true
dpkg -l | awk '/^ii.*gcc/{print $2}'      | xargs -r apt-get purge -y 2>/dev/null || true
dpkg -l | awk '/^ii.*g\+\+/{print $2}'    | xargs -r apt-get purge -y 2>/dev/null || true
dpkg -l | awk '/^ii  cpp/{print $2}'      | xargs -r apt-get purge -y 2>/dev/null || true
dpkg -l | awk '/^ii.*binutils/{print $2}' | xargs -r apt-get purge -y 2>/dev/null || true

# =============================================================
# PAS 10: Apps de desktop i càmera
# =============================================================
echo "[10/12] Eliminant apps de desktop innecessàries..."
apt-get purge -y \
  geany thonny mousepad \
  galculator \
  evince evince-common \
  eom eom-common \
  xarchiver \
  pcmanfm \
  rp-bookshelf \
  realvnc-vnc-server \
  rpi-connect \
  wayvnc \
  cloud-init cloud-guest-utils \
  agnostics \
  rpinters \
  sense-hat 2>/dev/null || true
dpkg -l | awk '/^ii.*pi-package/{print $2}'  | xargs -r apt-get purge -y 2>/dev/null || true
dpkg -l | awk '/^ii.*rpicam-apps/{print $2}' | xargs -r apt-get purge -y 2>/dev/null || true
dpkg -l | awk '/^ii.*libcamera/{print $2}'   | xargs -r apt-get purge -y 2>/dev/null || true

# =============================================================
# PAS 11: Kernels i headers antics (manté el kernel en execució)
# =============================================================
echo "[11/12] Eliminant kernels i headers antics..."

CURRENT_KERNEL=$(uname -r)
echo "    Kernel actiu: $CURRENT_KERNEL"

# Kernels antics (linux-image-*)
OLD_KERNELS=$(dpkg -l | awk '/^ii.*linux-image/{print $2}' | grep -v "$CURRENT_KERNEL" || true)
if [ -n "$OLD_KERNELS" ]; then
  echo "    Eliminant kernels: $OLD_KERNELS"
  echo "$OLD_KERNELS" | xargs -r apt-get purge -y
else
  echo "    No hi ha kernels antics."
fi

# Headers antics (linux-headers-*)
OLD_HEADERS=$(dpkg -l | awk '/^ii.*linux-headers/{print $2}' | grep -v "$CURRENT_KERNEL" || true)
if [ -n "$OLD_HEADERS" ]; then
  echo "    Eliminant headers: $OLD_HEADERS"
  echo "$OLD_HEADERS" | xargs -r apt-get purge -y
else
  echo "    No hi ha headers antics."
fi

# linux-kbuild antics
OLD_KBUILD=$(dpkg -l | awk '/^ii.*linux-kbuild/{print $2}' | grep -v "$CURRENT_KERNEL" || true)
if [ -n "$OLD_KBUILD" ]; then
  echo "    Eliminant kbuild: $OLD_KBUILD"
  echo "$OLD_KBUILD" | xargs -r apt-get purge -y
else
  echo "    No hi ha kbuild antics."
fi

# =============================================================
# PAS 12: Python - neteja total i reinstal·lació mínima
# =============================================================
echo "[12/12] Neteja total de Python i reinstal·lació mínima..."

# Guardar python3-minimal de la llista a purgar
dpkg -l | awk '/^ii.*python3-/{print $2}' | grep -v '^python3-minimal$' \
  | xargs -r apt-get purge -y 2>/dev/null || true
apt-get purge -y python3 python3-dev mypy pylint python-apt-common 2>/dev/null || true

# Eliminar paquets pip d'usuari
rm -rf /home/*/.local/lib/python* 2>/dev/null || true
rm -rf /root/.local/lib/python* 2>/dev/null || true

# Autoremove intermedi
apt-get autoremove -y --purge
apt-get autoclean -y

echo "    Reinstal·lant Python3 mínim + paho-mqtt..."
apt-get install -y \
  python3-minimal \
  python3-pip \
  python3-paho-mqtt

echo "    Verificant instal·lació paho-mqtt..."
python3 -c "import paho.mqtt.client; print('    paho-mqtt OK')"

# =============================================================
# Neteja final
# =============================================================
echo "=== Neteja final i desactivació de serveis ==="
apt-get autoremove -y --purge
apt-get autoclean -y
apt-get clean

for svc in \
  avahi-daemon \
  colord \
  cups \
  ModemManager \
  udisks2 \
  packagekit \
  accounts-daemon \
  rpcbind \
  blkmapd \
  nfs-client.target \
  triggerhappy \
  hciuart; do
  systemctl disable "$svc" 2>/dev/null || true
  systemctl stop    "$svc" 2>/dev/null || true
done

# Activar zram
systemctl enable systemd-zram-generator 2>/dev/null || true

# =============================================================
# Resum final
# =============================================================
FREE_MB=$(free -m | awk '/Mem/{print $2 - $3}')
TOTAL_MB=$(free -m | awk '/Mem/{print $2}')

echo ""
echo "========================================"
echo "  NETEJA COMPLETADA"
echo "========================================"
echo "  IP configurada : 192.168.1.18/24"
echo "  Gateway        : 192.168.1.1"
echo "  DNS            : 192.168.1.1"
echo "  Xarxa via      : systemd-networkd"
echo "  Python         : mínim + paho-mqtt"
echo "  Kernel actiu   : $(uname -r)"
echo "  RAM lliure     : ${FREE_MB} MB de ${TOTAL_MB} MB"
echo "========================================"
echo ""
echo "Comprova la xarxa ara (abans de reiniciar):"
echo "  ip addr show eth0"
echo "  ip route"
echo ""
echo "Reinicia amb: sudo reboot"
