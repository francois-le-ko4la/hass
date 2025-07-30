#!/bin/bash

# Collect system information

OUT="rasp_info.txt"

section() {
  echo -e "\n== $1 ==" >> "$OUT"
  eval "$2" >> "$OUT"
}

: > "$OUT"

echo -e "\n== Raspberry Pi Model ==" >> "$OUT"
cat /proc/device-tree/model >> "$OUT"
echo -e "\n" >> "$OUT"
section "Kernel & Architecture" "uname -a"
section "System Information" "hostnamectl | grep -v -E 'Machine ID|Boot ID'"
section "Raspberry Pi Hardware Revision" "grep Revision /proc/cpuinfo"
section "EEPROM" "sudo rpi-eeprom-update"
section "CPU Info" "lscpu"
section "Operating System Info" "cat /etc/os-release"

cp /etc/lsb-release lsb-release
cp /boot/firmware/cmdline.txt rasp_cmdline.txt
cp /boot/firmware/config.txt rasp_config.txt
cp /opt/docker-compose.yml docker-compose.yml

# Traitement du .env (masquer certaines valeurs)
awk '
/^\s*#/ || /^\s*$/ { print; next }  # lignes de commentaires ou vides
{
  split($0, kv, "=")
  key = kv[1]
  if (key == "TIME_ZONE" || key == "DOCKER_ROOT" || key == "HASS_ROOT") {
    print
  } else if (key == "ZIGBEE_ADAPTER_TTY") {
    print "ZIGBEE_ADAPTER_TTY=/dev/serial/by-id/XXX"
  } else {
    print key "=XXX"
  }
}
' /opt/.env > dotenv

# Nettoyage de configuration.yaml (suppression devices/groups, masquage IP et mot de passe)
awk '
  /^devices:/ { skip=1; next }
  /^groups:/ { skip=1; next }
  skip && /^[^[:space:]]/ { skip=0 }
  !skip {
    if ($1 == "password:") {
      print "  password: XXX"
    } else if ($1 == "server:") {
      sub(/mqtt:\/\/[^:]+/, "mqtt://XXX.XXX.XXX.XXX")
      print
    } else {
      print
    }
  }
' /opt/hass/zigbee2mqtt/data/configuration.yaml > Z2M_configuration.yaml

