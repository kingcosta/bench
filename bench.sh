#!/usr/bin/env bash
# ==============================================================================
# Linux Server Benchmark Skript (Inspiriert von bench.sh / superbench / yabs)
# Sprache: Bash (Vollständig auf Deutsch)
# Zeitzone: Europe/Berlin
# Enthält: System-Infos, Cloudflare WARP (Port 40000) Check, I/O & Speedtest
# ==============================================================================

# Zeitzone für alle Datums- und Zeitabfragen festlegen
export TZ="Europe/Berlin"

# Farben für ansprechendes Terminal-Design
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
BOLD="\033[1m"
RESET="\033[0m"

# Skript Version & Metadaten
VERSION="1.1.0"
BENCH_DATE=$(date "+%d.%m.%Y %H:%M:%S %Z")

# Temporäres Verzeichnis für I/O Tests
TMP_DIR=$(mktemp -d 2>/dev/null || echo "/tmp/bench_tmp")
TMP_FILE="${TMP_DIR}/test.img"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

# Trennlinien & Header
print_line() {
    echo -e "${CYAN}----------------------------------------------------------------------${RESET}"
}

print_header() {
    clear 2>/dev/null || true
    echo -e "${CYAN}======================================================================${RESET}"
    echo -e "${BOLD}${WHITE}                   LINUX SERVER BENCHMARK SKRIPT                     ${RESET}"
    echo -e "${YELLOW}                 System-Informationen & Performance-Test             ${RESET}"
    echo -e "${CYAN}======================================================================${RESET}"
    echo -e " ${BOLD}Version:${RESET} ${GREEN}${VERSION}${RESET}               ${BOLD}Datum (Europe/Berlin):${RESET} ${BENCH_DATE}"
    echo -e "${CYAN}----------------------------------------------------------------------${RESET}"
}

# Prüfen ob ein Befehl/Tool existiert
check_tool() {
    command -v "$1" >/dev/null 2>&1
}

# HTTP Downloader (curl oder wget)
download_file() {
    local url="$1"
    local output="$2"
    local timeout="${3:-15}"
    if check_tool curl; then
        curl -s -L -4 --max-time "$timeout" -o "$output" "$url"
    elif check_tool wget; then
        wget -q -4 -T "$timeout" -O "$output" "$url"
    else
        return 1
    fi
}

# Speedtest Hilfsfunktion (Misst Downloadrate in MB/s und Mbps)
speed_test_curl() {
    local node_name="$1"
    local url="$2"
    local ipv="$3"
    
    printf "%-26s" " $node_name"

    local ip_flag="-4"
    [[ "$ipv" == "6" ]] && ip_flag="-6"

    # Ping / Latenz messen
    local domain=$(echo "$url" | awk -F[/:] '{print $4}')
    local ping_time="N/A"
    if check_tool ping; then
        if [[ "$ipv" == "6" ]]; then
            ping_time=$(ping6 -c 2 -w 2 "$domain" 2>/dev/null | tail -1 | awk '{print $4}' | cut -d '/' -f 2)
        else
            ping_time=$(ping -c 2 -W 2 "$domain" 2>/dev/null | tail -1 | awk '{print $4}' | cut -d '/' -f 2)
        fi
        if [ -n "$ping_time" ]; then
            ping_time="${ping_time} ms"
        else
            ping_time="* Zeitüberschreitung"
        fi
    fi

    # Speedtest über curl
    if check_tool curl; then
        # Misst die Downloadrate über maximal 12 Sekunden
        local speed_raw=$(curl $ip_flag -s --max-time 12 -w "%{speed_download}" -o /dev/null "$url" 2>/dev/null)
        if [[ -n "$speed_raw" && "$speed_raw" != "0" ]]; then
            local speed_mb_s=$(awk -v s="$speed_raw" 'BEGIN {printf "%.2f", s / 1024 / 1024}')
            local speed_mbps=$(awk -v s="$speed_raw" 'BEGIN {printf "%.2f", (s * 8) / 1000 / 1000}')
            printf "%-16s %-16s %-12s\n" "$ping_time" "${speed_mb_s} MB/s" "${speed_mbps} Mbps"
            return
        fi
    fi

    printf "%-16s %-16s %-12s\n" "$ping_time" "${RED}Fehlgeschlagen${RESET}" "${RED}--${RESET}"
}

# ==============================================================================
# Cloudflare WARP (Port 40000) Prüffunktion
# ==============================================================================
check_cloudflare_warp_status() {
    local warp_installed=false
    local warp_service_running=false
    local port_40000_open=false
    local warp_socks_ok=false
    local warp_ip="N/A"
    local warp_loc="N/A"
    local warp_mode=""
    local warp_status_summary=""

    # 1. Prüfen ob warp-cli vorhanden ist
    if check_tool warp-cli || [ -f /usr/bin/warp-cli ] || [ -f /usr/local/bin/warp-cli ]; then
        warp_installed=true
    fi

    # 2. Prüfen ob warp-svc Prozess / systemd Dienst läuft
    if pgrep -f "warp-svc" >/dev/null 2>&1 || (check_tool systemctl && systemctl is-active --quiet warp-svc 2>/dev/null); then
        warp_service_running=true
    fi

    # 3. Prüfen ob Port 40000 lokal lauscht (TCP SOCKS5 / Proxy)
    if (echo > /dev/tcp/127.0.0.1/40000) 2>/dev/null; then
        port_40000_open=true
    elif check_tool ss && ss -tulpn 2>/dev/null | grep -q ":40000"; then
        port_40000_open=true
    elif check_tool netstat && netstat -tulpn 2>/dev/null | grep -q ":40000"; then
        port_40000_open=true
    fi

    # 4. Funktionsprüfung via Cloudflare CDN Trace über SOCKS5 Proxy Port 40000
    if check_tool curl; then
        local trace_out
        trace_out=$(curl -s -m 4 --socks5-hostname 127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null)
        if echo "$trace_out" | grep -q "warp=on\|warp=plus"; then
            warp_socks_ok=true
            warp_ip=$(echo "$trace_out" | awk -F= '/^ip=/ {print $2}')
            warp_loc=$(echo "$trace_out" | awk -F= '/^loc=/ {print $2}')
            warp_mode=$(echo "$trace_out" | awk -F= '/^warp=/ {print $2}')
        fi
    fi

    # Zusammenfassende Status-Meldung
    if [ "$warp_socks_ok" = true ]; then
        warp_status_summary="${GREEN}${BOLD}Aktiv & Verbunden${RESET} ${GREEN}(Port 40000 SOCKS5 | WARP=${warp_mode} | IP: ${warp_ip} [${warp_loc}])${RESET}"
    elif [ "$port_40000_open" = true ]; then
        warp_status_summary="${YELLOW}Port 40000 ist offen, aber WARP-Trace antwortet nicht${RESET}"
    elif [ "$warp_service_running" = true ]; then
        warp_status_summary="${YELLOW}Dienst (warp-svc) läuft, aber Port 40000 ist nicht erreichbar${RESET}"
    elif [ "$warp_installed" = true ]; then
        warp_status_summary="${YELLOW}warp-cli installiert, aber Dienst ist inaktiv / gestoppt${RESET}"
    else
        warp_status_summary="${RED}Nicht installiert / Port 40000 nicht aktiv${RESET}"
    fi

    echo "$warp_status_summary"
}

# Ausführliche WARP-Detaildiagnose
get_warp_detailed_report() {
    echo -e "${BOLD}${WHITE} -> CLOUDFLARE WARP DIAGNOSE (Port 40000)${RESET}"
    print_line
    
    local warp_cli_bin="Nein"
    if check_tool warp-cli; then
        warp_cli_bin="${GREEN}Installiert ($(warp-cli --version 2>/dev/null || echo "vorhanden"))${RESET}"
    else
        warp_cli_bin="${RED}Nicht gefunden${RESET}"
    fi

    local service_status="${RED}Inaktiv / Gestoppt${RESET}"
    if pgrep -f "warp-svc" >/dev/null 2>&1; then
        service_status="${GREEN}Aktiv (warp-svc Prozess läuft)${RESET}"
    elif check_tool systemctl && systemctl is-active --quiet warp-svc 2>/dev/null; then
        service_status="${GREEN}Aktiv (systemd)${RESET}"
    fi

    local port_status="${RED}Geschlossen / Nicht lauschend${RESET}"
    if (echo > /dev/tcp/127.0.0.1/40000) 2>/dev/null; then
        port_status="${GREEN}Geöffnet (127.0.0.1:40000 erreichbar)${RESET}"
    elif check_tool ss && ss -tulpn 2>/dev/null | grep -q ":40000"; then
        port_status="${GREEN}Geöffnet (ss -tulpn zeigt Port 40000)${RESET}"
    fi

    printf " %-24s: %b\n" "warp-cli Client" "$warp_cli_bin"
    printf " %-24s: %b\n" "warp-svc Hintergrunddienst" "$service_status"
    printf " %-24s: %b\n" "Port 40000 Status" "$port_status"

    if check_tool curl; then
        echo -e " ${YELLOW}Prüfe Verbindung über SOCKS5 Proxy 127.0.0.1:40000...${RESET}"
        local trace_out
        trace_out=$(curl -s -m 5 --socks5-hostname 127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null)
        if [ -n "$trace_out" ]; then
            local w_ip=$(echo "$trace_out" | awk -F= '/^ip=/ {print $2}')
            local w_warp=$(echo "$trace_out" | awk -F= '/^warp=/ {print $2}')
            local w_loc=$(echo "$trace_out" | awk -F= '/^loc=/ {print $2}')
            local w_colo=$(echo "$trace_out" | awk -F= '/^colo=/ {print $2}')
            printf " %-24s: %s (WARP-Status: %s)\n" "WARP IP-Adresse" "$w_ip" "$w_warp"
            printf " %-24s: %s (Cloudflare Colo: %s)\n" "WARP Standort" "$w_loc" "$w_colo"
        else
            printf " %-24s: %b\n" "WARP Trace Test" "${RED}Fehlgeschlagen (Keine Antwort über Port 40000)${RESET}"
        fi
    fi

    if check_tool warp-cli; then
        echo -e "\n ${BOLD}warp-cli Status-Ausgabe:${RESET}"
        warp-cli status 2>/dev/null || warp-cli --accept-tos status 2>/dev/null || echo "Keine Status-Rückmeldung von warp-cli."
    fi
    print_line
}

# ==============================================================================
# 1. System-Informationen auslesen
# ==============================================================================
get_system_info() {
    # CPU Informationen
    CPU_MODEL=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo 2>/dev/null | sed 's/^[ \t]*//')
    [ -z "$CPU_MODEL" ] && CPU_MODEL=$(lscpu 2>/dev/null | awk -F: '/Model name/ {print $2}' | sed 's/^[ \t]*//')
    [ -z "$CPU_MODEL" ] && CPU_MODEL="Unbekannte CPU"

    CPU_CORES=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1")
    CPU_FREQ=$(awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo 2>/dev/null | sed 's/^[ \t]*//')
    [ -n "$CPU_FREQ" ] && CPU_FREQ=$(printf "%.2f MHz" "$CPU_FREQ") || CPU_FREQ="N/A"
    
    CPU_CACHE=$(awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo 2>/dev/null | sed 's/^[ \t]*//')
    [ -z "$CPU_CACHE" ] && CPU_CACHE="N/A"

    # Hardware AES-NI Unterstützung
    if grep -q -E 'aes' /proc/cpuinfo; then
        AES_SUPPORT="${GREEN}Aktiviert${RESET}"
    else
        AES_SUPPORT="${YELLOW}Nicht vorhanden${RESET}"
    fi

    # Virtualisierung erkennen
    VIRT_TYPE="Dedicated / Baremetal (Echter Server)"
    if check_tool systemd-detect-virt; then
        VIRT_DETECT=$(systemd-detect-virt 2>/dev/null)
        if [ "$VIRT_DETECT" != "none" ] && [ -n "$VIRT_DETECT" ]; then
            VIRT_TYPE="${VIRT_DETECT^^}"
        fi
    fi
    if [[ "$VIRT_TYPE" == *"Dedicated"* ]]; then
        if grep -qa "KVM" /sys/class/dmi/id/sys_vendor 2>/dev/null || grep -qa "QEMU" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
            VIRT_TYPE="KVM"
        elif grep -qa "VMware" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
            VIRT_TYPE="VMware"
        elif grep -qa "Xen" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
            VIRT_TYPE="Xen"
        elif [ -f /proc/user_beancounters ]; then
            VIRT_TYPE="OpenVZ"
        elif [ -f /.dockerenv ]; then
            VIRT_TYPE="Docker Container"
        fi
    fi

    # Betriebssystem & Kernel
    if [ -f /etc/os-release ]; then
        OS_NAME=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    elif check_tool lsb_release; then
        OS_NAME=$(lsb_release -d | cut -f2)
    else
        OS_NAME=$(uname -s)
    fi
    KERNEL_VER=$(uname -r)
    ARCH=$(uname -m)

    # Cloudflare WARP Status prüfen
    WARP_STATUS=$(check_cloudflare_warp_status)

    # Arbeitsspeicher (RAM & SWAP)
    RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
    RAM_USED=$(free -h | awk '/Mem:/ {print $3}')
    RAM_FREE=$(free -h | awk '/Mem:/ {print $4}')
    RAM_AVAIL=$(free -h | awk '/Mem:/ {print $7}')
    [ -z "$RAM_AVAIL" ] && RAM_AVAIL="$RAM_FREE"

    SWAP_TOTAL=$(free -h | awk '/Swap:/ {print $2}')
    SWAP_USED=$(free -h | awk '/Swap:/ {print $3}')
    [ -z "$SWAP_TOTAL" ] && SWAP_TOTAL="0B"
    [ -z "$SWAP_USED" ] && SWAP_USED="0B"

    # Festplattenspeicher (Root-Partition)
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
    ROOT_FS=$(df -T / | awk 'NR==2 {print $2}')

    # Uptime & Load
    UPTIME=$(uptime -p 2>/dev/null || uptime | awk -F'( |,|:)+' '{d=1; for(i=1;i<=NF;i++) {if($i=="up") {print $(i+1)" "$(i+2); d=0; break;}}}')
    LOAD_AVG=$(awk '{print $1", "$2", "$3}' /proc/loadavg 2>/dev/null || uptime | awk -F'load average:' '{print $2}')

    # TCP Congestion Control (BBR Check)
    TCP_CC=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    [ -z "$TCP_CC" ] && TCP_CC="N/A"

    # Öffentliche IP & Geolocation
    IP_INFO_JSON=$(curl -s -m 5 http://ip-api.com/json/?fields=country,city,org,as,query 2>/dev/null)
    if [ -n "$IP_INFO_JSON" ]; then
        IPV4_ADDR=$(echo "$IP_INFO_JSON" | grep -o '"query":"[^"]*' | cut -d'"' -f4)
        GEO_COUNTRY=$(echo "$IP_INFO_JSON" | grep -o '"country":"[^"]*' | cut -d'"' -f4)
        GEO_CITY=$(echo "$IP_INFO_JSON" | grep -o '"city":"[^"]*' | cut -d'"' -f4)
        GEO_ISP=$(echo "$IP_INFO_JSON" | grep -o '"org":"[^"]*' | cut -d'"' -f4)
        GEO_ASN=$(echo "$IP_INFO_JSON" | grep -o '"as":"[^"]*' | cut -d'"' -f4)
    else
        IPV4_ADDR=$(curl -s -m 3 https://api.ipify.org 2>/dev/null || echo "N/A")
        GEO_COUNTRY="N/A"
        GEO_CITY="N/A"
        GEO_ISP="N/A"
        GEO_ASN="N/A"
    fi

    # IPv6 Check
    IPV6_ADDR=$(curl -s -6 -m 3 https://api64.ipify.org 2>/dev/null || echo "Nicht verfügbar")

    # Ausgabe der Systeminfos
    echo -e "${BOLD}${WHITE} -> SYSTEM-INFORMATIONEN${RESET}"
    print_line
    printf " %-24s: %s\n" "CPU Modell" "$CPU_MODEL"
    printf " %-24s: %s Kerne / %s Threads (@ %s)\n" "CPU Konfiguration" "$CPU_CORES" "$CPU_CORES" "$CPU_FREQ"
    printf " %-24s: %s | AES-NI: %b\n" "CPU Cache & Features" "$CPU_CACHE" "$AES_SUPPORT"
    printf " %-24s: %s (%s)\n" "Betriebssystem" "$OS_NAME" "$ARCH"
    printf " %-24s: %s\n" "Kernel-Version" "$KERNEL_VER"
    printf " %-24s: %s\n" "Virtualisierung" "$VIRT_TYPE"
    printf " %-24s: %b\n" "Cloudflare WARP (40000)" "$WARP_STATUS"
    printf " %-24s: %s (Belegt: %s | Verfügbar: %s)\n" "Arbeitsspeicher (RAM)" "$RAM_TOTAL" "$RAM_USED" "$RAM_AVAIL"
    printf " %-24s: %s (Belegt: %s)\n" "Swap-Speicher" "$SWAP_TOTAL" "$SWAP_USED"
    printf " %-24s: %s (Belegt: %s [%s] | Dateisystem: %s)\n" "Festplattenspeicher (/)" "$DISK_TOTAL" "$DISK_USED" "$DISK_USAGE" "$ROOT_FS"
    printf " %-24s: %s\n" "Systemlaufzeit (Uptime)" "$UPTIME"
    printf " %-24s: %s\n" "Lastdurchschnitt (Load)" "$LOAD_AVG"
    printf " %-24s: %s\n" "TCP-Algorithmus (BBR)" "$TCP_CC"
    printf " %-24s: %s, %s\n" "Standort (GeoIP)" "$GEO_CITY" "$GEO_COUNTRY"
    printf " %-24s: %s / %s\n" "Anbieter & ASN" "$GEO_ISP" "$GEO_ASN"
    printf " %-24s: %s\n" "Öffentliche IPv4" "$IPV4_ADDR"
    printf " %-24s: %s\n" "Öffentliche IPv6" "$IPV6_ADDR"
    print_line
}

# ==============================================================================
# 2. Festplatten I/O Geschwindigkeitstest
# ==============================================================================
get_disk_io() {
    echo -e "${BOLD}${WHITE} -> FESTPLATTEN I/O GESCHWINDIGKEIT (Sequentieller Schreibtest)${RESET}"
    print_line
    mkdir -p "$TMP_DIR"

    echo -e " ${YELLOW}Führe 3 sequentielle Schreib-Durchläufe durch (1 GB Blockgröße, fdatasync)...${RESET}"
    
    local io1=$( (dd if=/dev/zero of="${TMP_FILE}" bs=1M count=1024 conv=fdatasync 2>&1) | awk -F, '{io=$NF} END {print io}' | sed 's/^[ \t]*//' )
    rm -f "${TMP_FILE}"
    
    local io2=$( (dd if=/dev/zero of="${TMP_FILE}" bs=1M count=1024 conv=fdatasync 2>&1) | awk -F, '{io=$NF} END {print io}' | sed 's/^[ \t]*//' )
    rm -f "${TMP_FILE}"
    
    local io3=$( (dd if=/dev/zero of="${TMP_FILE}" bs=1M count=1024 conv=fdatasync 2>&1) | awk -F, '{io=$NF} END {print io}' | sed 's/^[ \t]*//' )
    rm -f "${TMP_FILE}"

    # Geschwindigkeitswerte extrahieren für Durchschnittsberechnung
    local val1=$(echo "$io1" | awk '{print $1}')
    local unit1=$(echo "$io1" | awk '{print $2}')
    local val2=$(echo "$io2" | awk '{print $1}')
    local val3=$(echo "$io3" | awk '{print $1}')

    # Wenn Werte in GB/s angegeben sind, auf MB/s umrechnen
    [[ "$unit1" == *"GB/s"* || "$unit1" == *"GiB/s"* ]] && val1=$(awk -v v="$val1" 'BEGIN {print v * 1024}')
    [[ "$io2" == *"GB/s"* || "$io2" == *"GiB/s"* ]] && val2=$(awk -v v="$val2" 'BEGIN {print v * 1024}')
    [[ "$io3" == *"GB/s"* || "$io3" == *"GiB/s"* ]] && val3=$(awk -v v="$val3" 'BEGIN {print v * 1024}')

    local avg_io="N/A"
    if [[ -n "$val1" && -n "$val2" && -n "$val3" ]]; then
        avg_io=$(awk -v a="$val1" -v b="$val2" -v c="$val3" 'BEGIN {printf "%.2f MB/s", (a + b + c) / 3}')
    fi

    printf " %-24s: %s\n" "1. Durchlauf (1 GB)" "$io1"
    printf " %-24s: %s\n" "2. Durchlauf (1 GB)" "$io2"
    printf " %-24s: %s\n" "3. Durchlauf (1 GB)" "$io3"
    printf " %-24s: ${BOLD}${GREEN}%s${RESET}\n" "Durchschnittliche I/O" "$avg_io"
    print_line
}

# ==============================================================================
# 3. CPU Benchmark (OpenSSL Benchmark)
# ==============================================================================
get_cpu_benchmark() {
    if ! check_tool openssl; then
        return
    fi
    echo -e "${BOLD}${WHITE} -> CPU-LEISTUNG (OpenSSL 3-Sekunden Krypto-Benchmark)${RESET}"
    print_line
    
    echo -e " ${YELLOW}Berechne Krypto-Durchsatz...${RESET}"
    local sha_single=$(openssl speed -seconds 3 sha256 2>&1 | awk '/^sha256/ {print $NF}' | tail -1)
    local aes_single=$(openssl speed -seconds 3 -evp aes-256-gcm 2>&1 | awk '/^aes-256-gcm/ {print $NF}' | tail -1)

    # Formatierung in MB/s
    if [[ -n "$sha_single" ]]; then
        sha_single=$(awk -v s="$sha_single" 'BEGIN {printf "%.2f MB/s", s / 1024 / 1024}')
    else
        sha_single="N/A"
    fi

    if [[ -n "$aes_single" ]]; then
        aes_single=$(awk -v s="$aes_single" 'BEGIN {printf "%.2f MB/s", s / 1024 / 1024}')
    else
        aes_single="N/A"
    fi

    printf " %-24s: %s\n" "SHA256 (Single-Thread)" "$sha_single"
    printf " %-24s: %s\n" "AES-256-GCM (Single)" "$aes_single"
    print_line
}

# ==============================================================================
# 4. Netzwerk-Geschwindigkeitstest
# ==============================================================================
get_network_speed() {
    echo -e "${BOLD}${WHITE} -> NETZWERK-GESCHWINDIGKEITSTEST (Weltweite Download-Knoten)${RESET}"
    print_line
    printf "${BOLD} %-25s %-16s %-16s %-12s${RESET}\n" "Knoten / Standort" "Latenz" "Geschwindigkeit" "Bitrate"
    print_line

    # Region: Deutschland & Europa
    speed_test_curl "Frankfurt, DE (Hetzner)" "https://fsn1-speed.hetzner.com/100MB.bin" "4"
    speed_test_curl "Nürnberg, DE (Hetzner)" "https://nbg1-speed.hetzner.com/100MB.bin" "4"
    speed_test_curl "Falkenstein, DE (OVH)" "http://de.proof.ovh.net/files/100Mb.dat" "4"
    speed_test_curl "Amsterdam, NL (Leaseweb)" "http://mirror.nl.leaseweb.net/speedtest/100mb.bin" "4"
    speed_test_curl "London, UK (Linode)" "http://speedtest.london.linode.com/100MB-london.bin" "4"
    speed_test_curl "Paris, FR (Scaleway)" "http://ping.online.net/100Mo.dat" "4"

    # Region: Nordamerika
    speed_test_curl "New York, US (Linode)" "http://speedtest.newark.linode.com/100MB-newark.bin" "4"
    speed_test_curl "Dallas, US (Linode)" "http://speedtest.dallas.linode.com/100MB-dallas.bin" "4"
    speed_test_curl "San Francisco, US (DO)" "http://speedtest-sfo1.digitalocean.com/100mb.test" "4"

    # Region: Asien / Ozeanien
    speed_test_curl "Singapur, SG (Linode)" "http://speedtest.singapore.linode.com/100MB-singapore.bin" "4"
    speed_test_curl "Tokio, JP (Linode)" "http://speedtest.tokyo2.linode.com/100MB-tokyo2.bin" "4"
    speed_test_curl "Sydney, AU (Linode)" "http://speedtest.sydney1.linode.com/100MB-sydney.bin" "4"

    print_line
}

# ==============================================================================
# Hilfe & Parameter-Verarbeitung
# ==============================================================================
show_help() {
    echo -e "${BOLD}Verwendung:${RESET} $0 [OPTION]"
    echo ""
    echo -e "${BOLD}Verfügbare Optionen:${RESET}"
    echo "  -i,   --info       Nur System- und Hardware-Informationen anzeigen"
    echo "  -w,   --warp       Ausführliche Cloudflare WARP (Port 40000) Diagnose"
    echo "  -io,  --disk       Nur Festplatten I/O Benchmark ausführen"
    echo "  -c,   --cpu        Nur CPU Krypto-Benchmark ausführen"
    echo "  -net, --network    Nur Netzwerk-Geschwindigkeitstest ausführen"
    echo "  -h,   --help       Diese Hilfe anzeigen"
    echo ""
    echo "Wird kein Parameter angegeben, wird der vollständige Benchmark ausgeführt."
    exit 0
}

main() {
    local opt="$1"

    case "$opt" in
        -i|--info)
            print_header
            get_system_info
            ;;
        -w|--warp)
            print_header
            get_warp_detailed_report
            ;;
        -io|--disk)
            print_header
            get_disk_io
            ;;
        -c|--cpu)
            print_header
            get_cpu_benchmark
            ;;
        -net|--network)
            print_header
            get_network_speed
            ;;
        -h|--help)
            show_help
            ;;
        *)
            print_header
            get_system_info
            get_disk_io
            get_cpu_benchmark
            get_network_speed
            ;;
    esac

    echo -e "${BOLD}${GREEN} Benchmark erfolgreich abgeschlossen!${RESET}"
    echo -e "${CYAN}======================================================================${RESET}"
}

main "$@"
