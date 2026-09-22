#!/usr/bin/env bash
#
# Heptarchia dedikált szerver telepítése egy friss Linux gépre.
# Kipróbálva Ubuntu 22.04/24.04-en, x86_64 és ARM64 (Oracle Ampere) gépen.
#
# Használat a szerveren:
#   curl -fsSL https://raw.githubusercontent.com/Parthenon2-boop/heptarchia/main/szerver/telepit.sh -o telepit.sh
#   less telepit.sh            # nézd át, mielőtt futtatod – ez jó szokás
#   sudo bash telepit.sh       # vagy: sudo bash telepit.sh 7777
#
# Mit csinál?
#   1. letölti a Godot 4.7.2 headless változatát a gép architektúrájához
#   2. letölti a játékot (git clone) és beimportálja az erőforrásait
#   3. létrehoz egy heptarchia nevű rendszerfelhasználót
#   4. beállít egy systemd szolgáltatást, ami újraindulás után is elindul
#   5. megnyitja a portot a gép tűzfalán
#
# Amit NEM tud megcsinálni: a felhőszolgáltató tűzfalát (Oracle VCN biztonsági
# lista / GCP firewall rule). Azt a webes felületen kell megnyitni – a szkript
# a végén emlékeztet rá.

set -euo pipefail

PORT="${1:-7777}"
GODOT_VERZIO="4.7.2"
REPO="https://github.com/Parthenon2-boop/heptarchia.git"
JATEK_MAPPA="/opt/heptarchia"
GODOT_MAPPA="/opt/godot"
ADAT_MAPPA="/var/lib/heptarchia"
FELHASZNALO="heptarchia"

uzenet() { printf "\n\033[1;33m── %s\033[0m\n" "$1"; }

if [[ $EUID -ne 0 ]]; then
	echo "Ezt rendszergazdaként kell futtatni:  sudo bash $0 $PORT" >&2
	exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
	echo "Érvénytelen port: $PORT" >&2
	exit 1
fi

uzenet "1/6 Szükséges csomagok"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git unzip wget ca-certificates

uzenet "2/6 Godot $GODOT_VERZIO (headless)"
case "$(uname -m)" in
	x86_64)          GODOT_FAJL="Godot_v${GODOT_VERZIO}-stable_linux.x86_64" ;;
	aarch64 | arm64) GODOT_FAJL="Godot_v${GODOT_VERZIO}-stable_linux.arm64" ;;
	*) echo "Ismeretlen architektúra: $(uname -m). Kézzel kell Godotot tenni ide: $GODOT_MAPPA/godot" >&2; exit 1 ;;
esac
mkdir -p "$GODOT_MAPPA"
if [[ ! -x "$GODOT_MAPPA/godot" ]]; then
	wget -q --show-progress \
		"https://github.com/godotengine/godot/releases/download/${GODOT_VERZIO}-stable/${GODOT_FAJL}.zip" \
		-O /tmp/godot.zip
	unzip -oq /tmp/godot.zip -d /tmp/godot_kicsomag
	mv "/tmp/godot_kicsomag/${GODOT_FAJL}" "$GODOT_MAPPA/godot"
	chmod +x "$GODOT_MAPPA/godot"
	rm -rf /tmp/godot.zip /tmp/godot_kicsomag
fi
"$GODOT_MAPPA/godot" --version

uzenet "3/6 A játék letöltése"
if [[ -d "$JATEK_MAPPA/.git" ]]; then
	git -C "$JATEK_MAPPA" pull --ff-only
else
	git clone --depth 1 "$REPO" "$JATEK_MAPPA"
fi

uzenet "4/6 Felhasználó és erőforrások importálása"
id -u "$FELHASZNALO" >/dev/null 2>&1 || useradd --system --home "$ADAT_MAPPA" --shell /usr/sbin/nologin "$FELHASZNALO"
mkdir -p "$ADAT_MAPPA"
chown -R "$FELHASZNALO:$FELHASZNALO" "$ADAT_MAPPA" "$JATEK_MAPPA"
# Az első importálás pár percig tart (a 273 uralkodókép miatt is).
sudo -u "$FELHASZNALO" HOME="$ADAT_MAPPA" "$GODOT_MAPPA/godot" --headless --path "$JATEK_MAPPA" --import || true

uzenet "5/6 systemd szolgáltatás (port: $PORT)"
echo "PORT=$PORT" > /etc/default/heptarchia-szerver
install -m 644 "$JATEK_MAPPA/szerver/heptarchia-szerver.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now heptarchia-szerver
sleep 3
systemctl --no-pager --lines=15 status heptarchia-szerver || true

uzenet "6/6 Tűzfal a gépen (UDP $PORT)"
if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
	firewall-cmd --permanent --add-port="${PORT}/udp"
	firewall-cmd --reload
	echo "firewalld: UDP $PORT megnyitva"
elif command -v iptables >/dev/null 2>&1; then
	# Az Oracle Linux/Ubuntu képek alapból zárt iptables-szel jönnek
	iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null || \
		iptables -I INPUT 1 -p udp --dport "$PORT" -j ACCEPT
	if command -v netfilter-persistent >/dev/null 2>&1; then
		netfilter-persistent save
	elif [[ -d /etc/iptables ]]; then
		iptables-save > /etc/iptables/rules.v4
	else
		echo "FIGYELEM: a szabály él, de újraindulás után eltűnhet."
		echo "          Telepítsd az iptables-persistent csomagot, ha maradandó kell."
	fi
	echo "iptables: UDP $PORT megnyitva"
else
	echo "Nem találtam tűzfalat – valószínűleg nincs is. Rendben."
fi

CIM="$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || echo '<a géped nyilvános IP-címe>')"

cat <<VEGE

══════════════════════════════════════════════════════════════════
  Kész. A szerver fut, és újraindulás után magától elindul.

  Csatlakozás a játékból:  Többjátékos → Csatlakozás
      cím:  $CIM
      port: $PORT

  MÉG EGY LÉPÉS, amit a felhő webes felületén kell megtenned:
    • Oracle Cloud: Networking → Virtual Cloud Networks → a VCN →
      Security Lists → Add Ingress Rule
         Source CIDR: 0.0.0.0/0   IP Protocol: UDP   Dest. Port: $PORT
    • Google Cloud: VPC network → Firewall → Create rule
         Targets: All instances   Source: 0.0.0.0/0   Protocol: udp:$PORT

  Hasznos parancsok:
    sudo systemctl restart heptarchia-szerver     # újraindítás
    sudo journalctl -u heptarchia-szerver -f      # mi történik éppen
    sudo bash $JATEK_MAPPA/szerver/telepit.sh $PORT   # frissítés új kiadásra
══════════════════════════════════════════════════════════════════

VEGE
