# MyHoneyPot

## Hardware

I decided to reuse my already over loaded raspberry pi 4b with this project. Usually its connected to the LAN thru Ethernet so wifi is free and seems a good option.

## Software

In my case tailscale is messing up all the network connections ... so first of all. But as my Rasp4b is also a RTSP server I'll need to activate it later. My Rasp4b has static ipv4 on eth0 192.168.1.0/24 (important because in wifi we will generate 192.168.2.0/24).
```
sudo systemctl stop tailscaled
```
Ready to go! Lets see that NetworkManager is up and running, wifi is on, current location ES, and lets delete old tests done about rpi-ap:
```
systemctl status NetworkManager --no-pager
sudo nmcli radio wifi on
sudo iw reg set ES
sudo nmcli connection delete rpi-ap 2>/dev/null || true
```
Create rpi-ap, it will generate a SSID called "SSID-For-IOT" with password "Password-For-SSID-IOT", also with a DHCP server serving 192.168.2.0/24 ips. 
```
sudo nmcli connection add \
  type wifi \
  ifname wlan0 \
  con-name rpi-ap \
  autoconnect no \
  ssid SSID-For-IOT
sudo nmcli connection modify rpi-ap \
  802-11-wireless.mode ap \
  802-11-wireless.band bg \
  ipv4.method shared \
  ipv4.addresses 192.168.2.0/24 \
  ipv6.method disabled
sudo nmcli connection modify rpi-ap \
  802-11-wireless-security.key-mgmt wpa-psk \
  802-11-wireless-security.proto rsn \
  802-11-wireless-security.pairwise ccmp \
  802-11-wireless-security.psk "Password-For-SSID-IOT"
sudo nmcli connection up rpi-ap
```
Check it:
```
nmcli device status
ip a show wlan0
```
Lets capture the traffic generated in the wifi, maybe during a startup, or while activating options thru cloud based mobile apps.
```
sudo tcpdump -i wlan0 -w /tmp/iot_clients.pcap
```
Lets activate back tailscale to acces from remote.
```
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
sudo tailscale up --accept-dns=false --accept-routes=false
```
