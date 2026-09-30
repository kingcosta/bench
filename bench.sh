#!/usr/bin/env bash
# ==============================================================================
#  ██████╗ ███████╗███╗   ██╗ ██████╗██╗  ██╗   ██████╗ ██╗   ██╗
#  ██╔══██╗██╔════╝████╗  ██║██╔════╝██║  ██║   ██╔══██╗╚██╗ ██╔╝
#  ██████╔╝█████╗  ██╔██╗ ██║██║     ███████║   ██████╔╝ ╚████╔╝ 
#  ██╔══██╗██╔══╝  ██║╚██╗██║██║     ██╔══██║   ██╔══██╗  ╚██╔╝  
#  ██████╔╝███████╗██║ ╚████║╚██████╗██║  ██║██╗██████╔╝   ██║   
#  ╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═════╝    ╚═╝   
#
#        ██████╗  ██████╗  ███████╗ ████████╗  █████╗ 
#       ██╔════╝ ██╔═══██╗ ██╔════╝ ╚══██╔══╝ ██╔══██╗
#       ██║      ██║   ██║ ███████╗    ██║    ███████║
#       ██║      ██║   ██║ ╚════██║    ██║    ██╔══██║
#       ╚██████╗ ╚██████╔╝ ███████║    ██║    ██║  ██║
#        ╚═════╝  ╚═════╝  ╚══════╝    ╚═╝    ╚═╝  ╚═╝
#
#  Linux Server Benchmark & Extended Hardware Diagnostics Suite
#  Vollständig auf Deutsch | Europe/Berlin | Detaillierte CPU/GPU/RAM/Disk Infos
#  Repository: https://github.com/kingcosta/bench
# ==============================================================================

# Zeitzone festlegen
export TZ="Europe/Berlin"

# ==============================================================================
# Farbschema (Moderne ANSI 256-Farben)
# ==============================================================================
if [ -t 1 ]; then
    C_RESET="\033[0m"
    C_BOLD="\033[1m"
    C_DIM="\033[2m"
    
    # Akzente & Rahmen
    C_BORDER="\033[38;5;39m"        # Leuchtendes Cyan
    C_BORDER_DIM="\033[38;5;240m"   # Dezentes Dunkelgrau
    C_TITLE="\033[1;38;5;81m"       # Eisblau fett
    C_LABEL="\033[38;5;251m"       # Helles Silbergrau
    C_VALUE="\033[1;38;5;255m"      # Reinweiß fett
    C_ACCENT="\033[1;38;5;214m"    # Warmes Bernstein-Gold
    
    # Status-Farben
    C_GREEN="\033[1;38;5;48m"      # Smaragdgrün
    C_YELLOW="\033[1;38;5;220m"    # Sonnengelb
    C_RED="\033[1;38;5;196m"       # Korallenrot
    C_CYAN="\033[1;38;5;51m"       # Türkis
    C_MAGENTA="\033[1;38;5;207m"   # Neon-Pink
else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_BORDER=""
    C_BORDER_DIM=""
    C_TITLE=""
    C_LABEL=""
    C_VALUE=""
    C_ACCENT=""
    C_GREEN=""
    C_YELLOW=""
    C_RED=""
    C_CYAN=""
    C_MAGENTA=""
fi

# Metadaten
VERSION="1.4.0"
BENCH_DATE=$(date "+%d.%m.%Y %H:%M:%S %Z")
BOX_WIDTH=78

# Globale Variablen zur Auswertung
AVG_IO_NUM=0
PEAK_NET_MBPS=0
SUM_NET_MBPS=0
COUNT_NET_TESTS=0
CPU_AES_NUM=0
CPU_SHA_NUM=0
HAS_AES=false
IS_BBR=false
WARP_IS_OK=false
WARP_STATUS_TEXT=""
WARP_IP_VAL=""
WARP_LOC_VAL=""
DISK_FULL_PERCENT=0

# Temporäres Verzeichnis für I/O Tests
TMP_DIR=$(mktemp -d 2>/dev/null || echo "/tmp/bench_tmp_$$")
TMP_FILE="${TMP_DIR}/test.img"

cleanup() {
    rm -rf "$TMP_DIR"
    echo -ne "\033[?25h" # Cursor wieder einblenden
}
trap cleanup EXIT INT TERM

# ==============================================================================
# UI Komponenten & Box-Drawing Layouts
# ==============================================================================

box_section_header() {
    local icon="$1"
    local title="$2"
    echo ""
    echo -e "${C_BORDER}┌─[ ${C_TITLE}${icon}  ${title}${C_BORDER} ]$(head -c $((BOX_WIDTH - ${#title} - ${#icon} - 8)) < /dev/zero | tr '\0' '─')┐${C_RESET}"
}

box_section_footer() {
    echo -e "${C_BORDER}└$(head -c $((BOX_WIDTH - 2)) < /dev/zero | tr '\0' '─')┘${C_RESET}"
}

box_row() {
    local label="$1"
    local value="$2"
    printf "${C_BORDER}│${C_RESET}  ${C_LABEL}%-26s${C_RESET} : ${C_VALUE}%b${C_RESET}\n" "$label" "$value"
}

print_banner() {
    clear 2>/dev/null || true
    echo -ne "\033[?25l" # Cursor während Benchmark verstecken
    echo -e "${C_BORDER}╭────────────────────────────────────────────────────────────────────────────╮${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}  ${C_CYAN}██████╗ ███████╗███╗   ██╗ ██████╗██╗  ██╗   ██████╗ ██╗   ██╗${C_RESET}            ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}  ${C_CYAN}██╔══██╗██╔════╝████╗  ██║██╔════╝██║  ██║   ██╔══██╗╚██╗ ██╔╝${C_RESET}            ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}  ${C_TITLE}██████╔╝█████╗  ██╔██╗ ██║██║     ███████║   ██████╔╝ ╚████╔╝${C_RESET}             ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}  ${C_TITLE}██╔══██╗██╔══╝  ██║╚██╗██║██║     ██╔══██║   ██╔══██╗  ╚██╔╝${C_RESET}              ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}  ${C_CYAN}██████╔╝███████╗██║ ╚████║╚██████╗██║  ██║██╗██████╔╝   ██║${C_RESET}               ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}  ${C_CYAN}╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═════╝    ╚═╝${C_RESET}               ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}│                                                                            │${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}             ${C_MAGENTA}██████╗  ██████╗  ███████╗ ████████╗  █████╗${C_RESET}                   ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}            ${C_MAGENTA}██╔════╝ ██╔═══██╗ ██╔════╝ ╚══██╔══╝ ██╔══██╗${C_RESET}                  ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}            ${C_TITLE}██║      ██║   ██║ ███████╗    ██║    ███████║${C_RESET}                  ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}            ${C_TITLE}██║      ██║   ██║ ╚════██║    ██║    ██╔══██║${C_RESET}                  ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}            ${C_MAGENTA}╚██████╗ ╚██████╔╝ ███████║    ██║    ██║  ██║${C_RESET}                  ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}             ${C_MAGENTA}╚═════╝  ╚═════╝  ╚══════╝    ╚═╝    ╚═╝  ╚═╝${C_RESET}                  ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}│                                                                            │${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}   ${C_BOLD}${WHITE}🚀 Detaillierter Server & Hardware Benchmark mit WARP Audit${C_RESET}               ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}│${C_RESET}   ${C_DIM}📅 ${BENCH_DATE}  │  🌐 Europe/Berlin  │  📦 v${VERSION}${C_RESET}           ${C_BORDER}│${C_RESET}"
    echo -e "${C_BORDER}╰────────────────────────────────────────────────────────────────────────────╯${C_RESET}"
}

check_tool() {
    command -v "$1" >/dev/null 2>&1
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

    WARP_IS_OK=false
    WARP_STATUS_TEXT=""
    WARP_IP_VAL=""
    WARP_LOC_VAL=""

    if check_tool warp-cli || [ -f /usr/bin/warp-cli ] || [ -f /usr/local/bin/warp-cli ]; then
        warp_installed=true
    fi

    if pgrep -f "warp-svc" >/dev/null 2>&1 || (check_tool systemctl && systemctl is-active --quiet warp-svc 2>/dev/null); then
        warp_service_running=true
    fi

    if (echo > /dev/tcp/127.0.0.1/40000) 2>/dev/null; then
        port_40000_open=true
    elif check_tool ss && ss -tulpn 2>/dev/null | grep -q ":40000"; then
        port_40000_open=true
    elif check_tool netstat && netstat -tulpn 2>/dev/null | grep -q ":40000"; then
        port_40000_open=true
    fi

    if check_tool curl; then
        local trace_out
        trace_out=$(curl -s -m 4 --socks5-hostname 127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null)
        if echo "$trace_out" | grep -q "warp=on\|warp=plus"; then
            warp_socks_ok=true
            warp_ip=$(echo "$trace_out" | awk -F= '/^ip=/ {print $2}')
            warp_loc=$(echo "$trace_out" | awk -F= '/^loc=/ {print $2}')
            warp_mode=$(echo "$trace_out" | awk -F= '/^warp=/ {print $2}')
            WARP_IS_OK=true
            WARP_IP_VAL="$warp_ip"
            WARP_LOC_VAL="$warp_loc"
        fi
    fi

    if [ "$warp_socks_ok" = true ]; then
        WARP_STATUS_TEXT="${C_GREEN}● AKTIV${C_RESET} ${C_DIM}[${C_RESET}${C_VALUE}Port 40000 SOCKS5${C_RESET}${C_DIM}]${C_RESET} ${C_GREEN}WARP=${warp_mode}${C_RESET} ${C_DIM}➜ IP: ${C_RESET}${C_CYAN}${warp_ip}${C_RESET} ${C_DIM}(${warp_loc})${C_RESET}"
    elif [ "$port_40000_open" = true ]; then
        WARP_STATUS_TEXT="${C_YELLOW}▲ PORT OFFEN${C_RESET} ${C_DIM}(Port 40000 lauscht, aber keine WARP-Trace Antwort)${C_RESET}"
    elif [ "$warp_service_running" = true ]; then
        WARP_STATUS_TEXT="${C_YELLOW}▲ DIENST LÄUFT${C_RESET} ${C_DIM}(warp-svc aktiv, aber Port 40000 geschlossen)${C_RESET}"
    elif [ "$warp_installed" = true ]; then
        WARP_STATUS_TEXT="${C_YELLOW}▲ INSTALLIERT${C_RESET} ${C_DIM}(warp-cli vorhanden, aber inaktiv)${C_RESET}"
    else
        WARP_STATUS_TEXT="${C_RED}○ NICHT AKTIV${C_RESET} ${C_DIM}(Kein Dienst auf Port 40000)${C_RESET}"
    fi
}

# ==============================================================================
# 1. System & Mainboard Spezifikationen
# ==============================================================================
get_system_info() {
    box_section_header "🖥️" "SYSTEM & MAINBOARD SPEZIFIKATIONEN"

    # Hardware / System-Hersteller & Modell
    local sys_vendor=""
    local sys_model=""
    [ -f /sys/class/dmi/id/sys_vendor ] && sys_vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
    [ -f /sys/class/dmi/id/product_name ] && sys_model=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
    local sys_full="${sys_vendor} ${sys_model}"
    [ -z "$(echo "$sys_full" | tr -d ' ')" ] && sys_full="Standard Server / Generic Hardware"

    # Mainboard & BIOS
    local board_name=""
    local bios_ver=""
    local bios_date=""
    [ -f /sys/class/dmi/id/board_name ] && board_name=$(cat /sys/class/dmi/id/board_name 2>/dev/null)
    [ -f /sys/class/dmi/id/bios_version ] && bios_ver=$(cat /sys/class/dmi/id/bios_version 2>/dev/null)
    [ -f /sys/class/dmi/id/bios_date ] && bios_date=$(cat /sys/class/dmi/id/bios_date 2>/dev/null)
    local board_info="${board_name:-Unbekanntes Board} ${C_DIM}(BIOS: ${bios_ver:-N/A} vom ${bios_date:-N/A})${C_RESET}"

    # Virtualisierung
    local virt_type="Dedicated / Baremetal (Physischer Server)"
    if check_tool systemd-detect-virt; then
        local virt_detect=$(systemd-detect-virt 2>/dev/null)
        if [ "$virt_detect" != "none" ] && [ -n "$virt_detect" ]; then
            virt_type="${virt_detect^^}"
        fi
    fi
    if [[ "$virt_type" == *"Dedicated"* ]]; then
        if grep -qa "KVM" /sys/class/dmi/id/sys_vendor 2>/dev/null || grep -qa "QEMU" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
            virt_type="KVM (Kernel-based Virtual Machine)"
        elif grep -qa "VMware" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
            virt_type="VMware ESXi"
        elif grep -qa "Xen" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
            virt_type="Xen Hypervisor"
        elif [ -f /proc/user_beancounters ]; then
            virt_type="OpenVZ Container"
        elif [ -f /.dockerenv ]; then
            virt_type="Docker Container"
        fi
    fi

    # OS & Kernel
    local os_name=""
    if [ -f /etc/os-release ]; then
        os_name=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    elif check_tool lsb_release; then
        os_name=$(lsb_release -d | cut -f2)
    else
        os_name=$(uname -s)
    fi
    local kernel_ver=$(uname -r)
    local arch=$(uname -m)

    # WARP Status ermitteln (direkt in Haupt-Shell ohne Subshell)
    check_cloudflare_warp_status

    # Uptime & Load
    local uptime_val=$(uptime -p 2>/dev/null | sed 's/^up //' || uptime | awk -F'( |,|:)+' '{d=1; for(i=1;i<=NF;i++) {if($i=="up") {print $(i+1)" "$(i+2); d=0; break;}}}')
    local load_avg=$(awk '{print $1", "$2", "$3}' /proc/loadavg 2>/dev/null || uptime | awk -F'load average:' '{print $2}')

    # TCP BBR
    local tcp_cc=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    [ -z "$tcp_cc" ] && tcp_cc="N/A"
    local tcp_cc_display="${C_YELLOW}${tcp_cc} (Standard, BBR empfohlen)${C_RESET}"
    if [[ "$tcp_cc" == "bbr" ]]; then
        IS_BBR=true
        tcp_cc_display="${C_GREEN}bbr (Optimiert für Speed & Latenz)${C_RESET}"
    fi

    # IP & Geolocation
    local ip_info_json=$(curl -s -m 5 http://ip-api.com/json/?fields=country,city,org,as,query 2>/dev/null)
    local ipv4_addr="N/A"
    local geo_country="N/A"
    local geo_city="N/A"
    local geo_isp="N/A"
    local geo_asn="N/A"

    if [ -n "$ip_info_json" ]; then
        ipv4_addr=$(echo "$ip_info_json" | grep -o '"query":"[^"]*' | cut -d'"' -f4)
        geo_country=$(echo "$ip_info_json" | grep -o '"country":"[^"]*' | cut -d'"' -f4)
        geo_city=$(echo "$ip_info_json" | grep -o '"city":"[^"]*' | cut -d'"' -f4)
        geo_isp=$(echo "$ip_info_json" | grep -o '"org":"[^"]*' | cut -d'"' -f4)
        geo_asn=$(echo "$ip_info_json" | grep -o '"as":"[^"]*' | cut -d'"' -f4)
    else
        ipv4_addr=$(curl -s -m 3 https://api.ipify.org 2>/dev/null || echo "N/A")
    fi

    local ipv6_addr=$(curl -s -6 -m 3 https://api64.ipify.org 2>/dev/null || echo "Nicht zugewiesen / Deaktiviert")

    # Ausgabe Box 1
    box_row "System / Plattform" "${sys_full}"
    box_row "Mainboard & BIOS" "${board_info}"
    box_row "Virtualisierung" "${virt_type}"
    box_row "Betriebssystem" "${os_name} (${arch})"
    box_row "Kernel-Version" "${kernel_ver}"
    box_row "Cloudflare WARP (40000)" "${WARP_STATUS_TEXT}"
    box_row "Systemlaufzeit" "${uptime_val}"
    box_row "Lastdurchschnitt (Load)" "${load_avg}"
    box_row "TCP Algorithmus" "${tcp_cc_display}"
    box_row "Standort (GeoIP)" "${geo_city}, ${geo_country}"
    box_row "ISP & AS-Nummer" "${geo_isp} ${C_DIM}(${geo_asn})${C_RESET}"
    box_row "Öffentliche IPv4" "${C_CYAN}${ipv4_addr}${C_RESET}"
    box_row "Öffentliche IPv6" "${C_CYAN}${ipv6_addr}${C_RESET}"
    box_section_footer
}

# ==============================================================================
# 2. Detaillierte CPU-Analyse
# ==============================================================================
get_cpu_details() {
    box_section_header "⚡" "PROZESSOR (CPU) DETAIL-ANALYSE"

    # CPU Modell
    local cpu_model=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo 2>/dev/null | sed 's/^[ \t]*//')
    [ -z "$cpu_model" ] && cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {print $2}' | sed 's/^[ \t]*//')
    [ -z "$cpu_model" ] && cpu_model="Standard x86/ARM Prozessor"

    # CPU Architektur & Vendor
    local cpu_vendor=$(awk -F: '/vendor_id/ {print $2}' /proc/cpuinfo 2>/dev/null | head -1 | sed 's/^[ \t]*//')
    [ -z "$cpu_vendor" ] && cpu_vendor=$(lscpu 2>/dev/null | awk -F: '/Vendor ID/ {print $2}' | sed 's/^[ \t]*//')
    [ -z "$cpu_vendor" ] && cpu_vendor="Unbekannt"

    # Topologie: Sockets, Kerne, Threads
    local sockets=$(lscpu 2>/dev/null | awk -F: '/Socket\(s\):/ {print $2}' | tr -d ' ')
    [ -z "$sockets" ] && sockets="1"
    local cores_per_socket=$(lscpu 2>/dev/null | awk -F: '/Core\(s\) per socket:/ {print $2}' | tr -d ' ')
    local total_threads=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "1")
    local total_cores=$(( sockets * ${cores_per_socket:-total_threads} ))

    # Frequenz: Aktuell, Min, Max
    local cur_freq=$(awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo 2>/dev/null | sed 's/^[ \t]*//')
    local max_freq=$(lscpu 2>/dev/null | awk -F: '/CPU max MHz:/ {print $2}' | tr -d ' ')
    local min_freq=$(lscpu 2>/dev/null | awk -F: '/CPU min MHz:/ {print $2}' | tr -d ' ')
    [ -n "$cur_freq" ] && cur_freq=$(printf "%.1f MHz" "$cur_freq") || cur_freq="N/A"
    [ -n "$max_freq" ] && max_freq=$(printf "%.1f MHz" "$max_freq") || max_freq=""
    [ -n "$min_freq" ] && min_freq=$(printf "%.1f MHz" "$min_freq") || min_freq=""

    local freq_str="$cur_freq"
    if [ -n "$max_freq" ] && [ -n "$min_freq" ]; then
        freq_str="${cur_freq} ${C_DIM}(Min: ${min_freq} │ Max: ${max_freq})${C_RESET}"
    fi

    # Scaling Governor
    local governor="N/A"
    [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ] && governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver ] && governor="${governor} [$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null)]"

    # Caches (L1, L2, L3)
    local l1d=$(lscpu 2>/dev/null | awk -F: '/L1d cache:/ {print $2}' | sed 's/^[ \t]*//')
    local l1i=$(lscpu 2>/dev/null | awk -F: '/L1i cache:/ {print $2}' | sed 's/^[ \t]*//')
    local l2=$(lscpu 2>/dev/null | awk -F: '/L2 cache:/ {print $2}' | sed 's/^[ \t]*//')
    local l3=$(lscpu 2>/dev/null | awk -F: '/L3 cache:/ {print $2}' | sed 's/^[ \t]*//')
    local cache_summary=""
    [ -n "$l1d" ] && cache_summary="L1d: ${l1d} │ "
    [ -n "$l2" ] && cache_summary="${cache_summary}L2: ${l2} │ "
    [ -n "$l3" ] && cache_summary="${cache_summary}L3: ${l3}"
    [ -z "$cache_summary" ] && cache_summary=$(awk -F: '/cache size/ {print $2}' /proc/cpuinfo 2>/dev/null | head -1 | sed 's/^[ \t]*//')
    [ -z "$cache_summary" ] && cache_summary="N/A"

    # Befehlssätze & Features
    local features=()
    if grep -q -E 'aes' /proc/cpuinfo; then
        features+=("${C_GREEN}AES-NI${C_RESET}")
        HAS_AES=true
    else
        features+=("${C_DIM}Kein AES-NI${C_RESET}")
        HAS_AES=false
    fi

    grep -q -E 'avx512' /proc/cpuinfo && features+=("${C_GREEN}AVX-512${C_RESET}") || (grep -q -E 'avx2' /proc/cpuinfo && features+=("${C_GREEN}AVX2${C_RESET}") || (grep -q -E 'avx' /proc/cpuinfo && features+=("${C_GREEN}AVX${C_RESET}")))
    grep -q -E 'vmx|svm' /proc/cpuinfo && features+=("${C_GREEN}VT-x/AMD-V (Virtualisierung)${C_RESET}")
    grep -q -E 'sse4_2' /proc/cpuinfo && features+=("${C_GREEN}SSE4.2${C_RESET}")

    local feature_str=""
    for f in "${features[@]}"; do
        [ -n "$feature_str" ] && feature_str="${feature_str} │ $f" || feature_str="$f"
    done

    # Ausgabe Box 2
    box_row "CPU Modell" "${cpu_model}"
    box_row "Hersteller / Vendor" "${cpu_vendor}"
    box_row "Topologie" "${sockets} Socket(s) │ ${total_cores} Kerne │ ${total_threads} Threads"
    box_row "Taktfrequenz" "${freq_str}"
    box_row "CPU Governor" "${governor}"
    box_row "Cache-Größen" "${cache_summary}"
    box_row "Instruktions-Sets" "${feature_str}"
    box_section_footer
}

# ==============================================================================
# 3. Detaillierte GPU-Analyse (Grafikkarte & Beschleuniger)
# ==============================================================================
get_gpu_details() {
    box_section_header "🎮" "GRAFIKKARTE (GPU) & BESCHLEUNIGER"

    local gpu_found=false

    # 1. Prüfen auf NVIDIA GPU via nvidia-smi
    if check_tool nvidia-smi; then
        local nv_count=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [[ -n "$nv_count" && "$nv_count" -gt 0 ]]; then
            gpu_found=true
            local nv_info=$(nvidia-smi --query-gpu=name,memory.total,driver_version,temperature.gpu,power.draw --format=csv,noheader,nounits 2>/dev/null | head -1)
            local g_name=$(echo "$nv_info" | awk -F, '{print $1}' | sed 's/^[ \t]*//')
            local g_mem=$(echo "$nv_info" | awk -F, '{print $2}' | tr -d ' ')
            local g_drv=$(echo "$nv_info" | awk -F, '{print $3}' | tr -d ' ')
            local g_temp=$(echo "$nv_info" | awk -F, '{print $4}' | tr -d ' ')
            local g_pwr=$(echo "$nv_info" | awk -F, '{print $5}' | tr -d ' ')
            local cuda_ver=$(nvidia-smi 2>/dev/null | grep -i "CUDA Version" | awk '{print $9}')

            box_row "NVIDIA GPU Modell" "${C_GREEN}${g_name}${C_RESET} ${C_DIM}(Anzahl: ${nv_count})${C_RESET}"
            box_row "VRAM Speicher" "${g_mem} MB GDDR"
            box_row "Treiber & CUDA" "Treiber: ${g_drv} │ CUDA: ${cuda_ver:-N/A}"
            box_row "Status & Temperatur" "${g_temp} °C │ Leistungsaufnahme: ${g_pwr} W"
        fi
    fi

    # 2. Prüfen auf AMD GPU via rocm-smi oder lspci
    if [ "$gpu_found" = false ] && check_tool rocm-smi; then
        local amd_name=$(rocm-smi --showproductname 2>/dev/null | grep "Card series:" | awk -F: '{print $2}' | sed 's/^[ \t]*//')
        if [ -n "$amd_name" ]; then
            gpu_found=true
            box_row "AMD Radeon GPU" "${C_GREEN}${amd_name}${C_RESET}"
        fi
    fi

    # 3. Fallback: lspci Suche nach VGA / 3D Controller
    if [ "$gpu_found" = false ] && check_tool lspci; then
        local pci_gpus=$(lspci 2>/dev/null | grep -iE '3d controller|vga compatible controller|display controller')
        if [ -n "$pci_gpus" ]; then
            while IFS= read -r line; do
                local clean_gpu=$(echo "$line" | sed -E 's/^[0-9a-fA-F:.]+\s+(VGA compatible controller|3D controller|Display controller):\s+//')
                # Prüfen ob nicht nur VirtIO / QXL / Standard Cirrus
                if [[ "$clean_gpu" =~ (NVIDIA|GeForce|Tesla|Quadro|AMD|Radeon|Intel|Arc|Iris) ]]; then
                    gpu_found=true
                    box_row "Dedizierte/iGPU" "${C_GREEN}${clean_gpu}${C_RESET}"
                fi
            done <<< "$pci_gpus"
        fi
    fi

    # 4. Keine dedizierte GPU gefunden
    if [ "$gpu_found" = false ]; then
        box_row "GPU Status" "${C_DIM}Keine dedizierte GPU gefunden (Headless Cloud-Server / Standard-VGA)${C_RESET}"
    fi

    box_section_footer
}

# ==============================================================================
# 4. Detaillierte Speicher & Laufwerks-Analyse (RAM & Storage)
# ==============================================================================
get_storage_details() {
    box_section_header "💾" "SPEICHER & LAUFWERKE (RAM & STORAGE)"

    # RAM Details
    local ram_total=$(free -h | awk '/Mem:/ {print $2}')
    local ram_used=$(free -h | awk '/Mem:/ {print $3}')
    local ram_free=$(free -h | awk '/Mem:/ {print $4}')
    local ram_avail=$(free -h | awk '/Mem:/ {print $7}')
    [ -z "$ram_avail" ] && ram_avail="$ram_free"

    # RAM Typ (DDR4/DDR5/ECC) falls dmidecode verfügbar und mit Rechten
    local ram_type_speed=""
    if check_tool dmidecode && [ "$EUID" -eq 0 ]; then
        local dmi_type=$(dmidecode -t memory 2>/dev/null | grep "Type:" | grep -viE "error|unknown|^[ \t]*Type:[ \t]*RAM$|^[ \t]*Type:[ \t]*Other$" | head -1 | awk '{print $2}')
        local dmi_speed=$(dmidecode -t memory 2>/dev/null | grep "Speed:" | grep -viE "unknown|configured|none" | head -1 | sed 's/^[ \t]*Speed:[ \t]*//' | tr -d '\r\n')
        
        if [ -n "$dmi_type" ] && [ "$dmi_type" != "RAM" ] && [ "$dmi_type" != "Other" ] && [ "$dmi_type" != "Unknown" ]; then
            if [ -n "$dmi_speed" ] && [ "$dmi_speed" != "Unknown" ]; then
                ram_type_speed="${dmi_type} @ ${dmi_speed}"
            else
                ram_type_speed="${dmi_type}"
            fi
        fi
    fi

    local ram_display="${ram_total} ${C_DIM}(Belegt: ${ram_used} │ Frei: ${ram_avail})${C_RESET}"
    [ -n "$ram_type_speed" ] && ram_display="${ram_display} ${C_DIM}[${ram_type_speed}]${C_RESET}"

    # Swap & ZRAM
    local swap_total=$(free -h | awk '/Swap:/ {print $2}')
    local swap_used=$(free -h | awk '/Swap:/ {print $3}')
    local swap_display="${swap_total} ${C_DIM}(Belegt: ${swap_used})${C_RESET}"
    if [ -f /proc/swaps ] && grep -q "zram" /proc/swaps 2>/dev/null; then
        swap_display="${swap_display} ${C_GREEN}[ZRAM aktiv]${C_RESET}"
    fi

    # Physische Datenträger (NVMe, SSD, HDD, VirtIO)
    local disk_list=""
    if check_tool lsblk; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            local d_name=$(echo "$line" | awk '{print $1}')
            local d_size=$(echo "$line" | awk '{print $2}')
            local d_tran=$(echo "$line" | awk '{print $3}')
            local d_model=$(echo "$line" | awk '{$1=""; $2=""; $3=""; print $0}' | sed 's/^[ \t]*//;s/[ \t]*$//')

            local d_info=""
            if [ -n "$d_model" ] && [ -n "$d_tran" ] && [ "$d_tran" != "-" ]; then
                d_info="${d_tran^^} │ ${d_model}"
            elif [ -n "$d_model" ]; then
                d_info="${d_model}"
            elif [ -n "$d_tran" ] && [ "$d_tran" != "-" ]; then
                d_info="${d_tran^^}"
            else
                d_info="Standard Block Device"
            fi

            if [ -n "$disk_list" ]; then
                disk_list="${disk_list}\n• ${d_name} (${d_size}, ${d_info})"
            else
                disk_list="• ${d_name} (${d_size}, ${d_info})"
            fi
        done < <(lsblk -d -n -o NAME,SIZE,TRAN,MODEL 2>/dev/null | grep -E 'disk' | grep -v 'loop\|ram\|sr')
    fi

    # Root-Dateisystem
    local root_total=$(df -h / | awk 'NR==2 {print $2}')
    local root_used=$(df -h / | awk 'NR==2 {print $3}')
    local root_free=$(df -h / | awk 'NR==2 {print $4}')
    local root_usage=$(df -h / | awk 'NR==2 {print $5}')
    local root_fs=$(df -T / | awk 'NR==2 {print $2}')
    DISK_FULL_PERCENT=$(echo "$root_usage" | tr -d '%')

    # I/O Scheduler des Root-Laufwerks
    local root_dev=$(df / | awk 'NR==2 {print $1}' | sed 's/[0-9]*$//;s/p$//;s/\/dev\///')
    local io_scheduler="N/A"
    [ -f "/sys/block/${root_dev}/queue/scheduler" ] && io_scheduler=$(cat "/sys/block/${root_dev}/queue/scheduler" 2>/dev/null | grep -o '\[.*\]' | tr -d '[]')

    box_row "Arbeitsspeicher (RAM)" "${ram_display}"
    box_row "Swap-Speicher" "${swap_display}"
    box_row "Root Partition (/)" "${root_total} ${C_DIM}(Belegt: ${root_used} [${root_usage}] │ Frei: ${root_free} │ Dateisystem: ${root_fs})${C_RESET}"
    box_row "I/O Scheduler" "${io_scheduler:-none}"

    if [ -n "$disk_list" ]; then
        printf "${C_BORDER}│${C_RESET}  ${C_LABEL}%-26s${C_RESET} :\n" "Erkannte Laufwerke"
        echo -e "$disk_list" | while IFS= read -r line; do
            [ -n "$line" ] && echo -e "${C_BORDER}│${C_RESET}    ${C_VALUE}${line}${C_RESET}"
        done
    fi

    box_section_footer
}

# ==============================================================================
# 5. Festplatten I/O Benchmark
# ==============================================================================
get_disk_io() {
    box_section_header "🚀" "FESTPLATTEN I/O LEISTUNG (Sequentieller Schreibtest)"
    mkdir -p "$TMP_DIR"

    echo -ne "${C_BORDER}│${C_RESET}  ${C_ACCENT}⏳ 1/3 Sequentieller Schreibtest läuft (1 GB, fdatasync)...${C_RESET}\r"
    local io1=$( (dd if=/dev/zero of="${TMP_FILE}" bs=1M count=1024 conv=fdatasync 2>&1) | awk -F, '{io=$NF} END {print io}' | sed 's/^[ \t]*//' )
    rm -f "${TMP_FILE}"
    
    echo -ne "${C_BORDER}│${C_RESET}  ${C_ACCENT}⏳ 2/3 Sequentieller Schreibtest läuft (1 GB, fdatasync)...${C_RESET}\r"
    local io2=$( (dd if=/dev/zero of="${TMP_FILE}" bs=1M count=1024 conv=fdatasync 2>&1) | awk -F, '{io=$NF} END {print io}' | sed 's/^[ \t]*//' )
    rm -f "${TMP_FILE}"
    
    echo -ne "${C_BORDER}│${C_RESET}  ${C_ACCENT}⏳ 3/3 Sequentieller Schreibtest läuft (1 GB, fdatasync)...${C_RESET}\r"
    local io3=$( (dd if=/dev/zero of="${TMP_FILE}" bs=1M count=1024 conv=fdatasync 2>&1) | awk -F, '{io=$NF} END {print io}' | sed 's/^[ \t]*//' )
    rm -f "${TMP_FILE}"
    echo -ne "\033[K"

    local val1=$(echo "$io1" | awk '{print $1}')
    local unit1=$(echo "$io1" | awk '{print $2}')
    local val2=$(echo "$io2" | awk '{print $1}')
    local val3=$(echo "$io3" | awk '{print $1}')

    [[ "$unit1" == *"GB/s"* || "$unit1" == *"GiB/s"* ]] && val1=$(awk -v v="$val1" 'BEGIN {print v * 1024}')
    [[ "$io2" == *"GB/s"* || "$io2" == *"GiB/s"* ]] && val2=$(awk -v v="$val2" 'BEGIN {print v * 1024}')
    [[ "$io3" == *"GB/s"* || "$io3" == *"GiB/s"* ]] && val3=$(awk -v v="$val3" 'BEGIN {print v * 1024}')

    local avg_io="N/A"
    if [[ -n "$val1" && -n "$val2" && -n "$val3" ]]; then
        avg_io=$(awk -v a="$val1" -v b="$val2" -v c="$val3" 'BEGIN {printf "%.2f MB/s", (a + b + c) / 3}')
        AVG_IO_NUM=$(awk -v a="$val1" -v b="$val2" -v c="$val3" 'BEGIN {printf "%.2f", (a + b + c) / 3}')
    fi

    box_row "1. Durchlauf (1 GB)" "${io1}"
    box_row "2. Durchlauf (1 GB)" "${io2}"
    box_row "3. Durchlauf (1 GB)" "${io3}"
    box_row "Durchschnittliche I/O" "${C_GREEN}${C_BOLD}${avg_io}${C_RESET}"
    box_section_footer
}

# ==============================================================================
# 6. CPU Benchmark
# ==============================================================================
get_cpu_benchmark() {
    if ! check_tool openssl; then
        return
    fi
    box_section_header "⚡" "CPU KRYPTO-PERFORMANCE (OpenSSL Benchmark)"
    
    echo -ne "${C_BORDER}│${C_RESET}  ${C_ACCENT}⏳ Berechne SHA256 & AES-256-GCM Durchsatz...${C_RESET}\r"
    local sha_single=$(openssl speed -seconds 3 sha256 2>&1 | awk '/^sha256/ {print $NF}' | tail -1)
    local aes_single=$(openssl speed -seconds 3 -evp aes-256-gcm 2>&1 | awk '/^aes-256-gcm/ {print $NF}' | tail -1)
    echo -ne "\033[K"

    if [[ -n "$sha_single" ]]; then
        CPU_SHA_NUM=$(awk -v s="$sha_single" 'BEGIN {printf "%.2f", s / 1024 / 1024}')
        sha_single="${CPU_SHA_NUM} MB/s"
    else
        sha_single="N/A"
    fi

    if [[ -n "$aes_single" ]]; then
        CPU_AES_NUM=$(awk -v s="$aes_single" 'BEGIN {printf "%.2f", s / 1024 / 1024}')
        aes_single="${CPU_AES_NUM} MB/s"
    else
        aes_single="N/A"
    fi

    box_row "SHA256 (Single-Thread)" "${sha_single}"
    box_row "AES-256-GCM (Single)" "${aes_single}"
    box_section_footer
}

# ==============================================================================
# 7. Netzwerk Speedtest
# ==============================================================================
test_single_node() {
    local flag="$1"
    local node_name="$2"
    local url="$3"
    local ipv="$4"

    echo -ne "${C_BORDER}│${C_RESET}  ${C_ACCENT}⏳ Teste ${node_name}...${C_RESET}\r"

    local ip_flag="-4"
    [[ "$ipv" == "6" ]] && ip_flag="-6"

    # Ping messen
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
            ping_time="* timeout"
        fi
    fi

    local speed_mb_s="0.00 MB/s"
    local speed_mbps="0.00 Mbps"
    local status_color="${C_RED}"

    if check_tool curl; then
        local speed_raw=$(curl $ip_flag -s --max-time 12 -w "%{speed_download}" -o /dev/null "$url" 2>/dev/null)
        if [[ -n "$speed_raw" && "$speed_raw" != "0" ]]; then
            local mb_s=$(awk -v s="$speed_raw" 'BEGIN {printf "%.2f", s / 1024 / 1024}')
            local mbps=$(awk -v s="$speed_raw" 'BEGIN {printf "%.2f", (s * 8) / 1000 / 1000}')
            speed_mb_s="${mb_s} MB/s"
            speed_mbps="${mbps} Mbps"
            status_color="${C_GREEN}"

            local mbps_val=$(echo "$mbps" | awk '{print $1}')
            PEAK_NET_MBPS=$(awk -v cur="$PEAK_NET_MBPS" -v new="$mbps_val" 'BEGIN {if (new > cur) print new; else print cur}')
            SUM_NET_MBPS=$(awk -v cur="$SUM_NET_MBPS" -v add="$mbps_val" 'BEGIN {print cur + add}')
            COUNT_NET_TESTS=$((COUNT_NET_TESTS + 1))
        fi
    fi

    echo -ne "\033[K"
    printf "${C_BORDER}│${C_RESET}  %s %-25s ${C_DIM}│${C_RESET} %-12s ${C_DIM}│${C_RESET} ${status_color}%-14s${C_RESET} ${C_DIM}│${C_RESET} ${C_BOLD}%-12s${C_RESET}\n" \
           "$flag" "$node_name" "$ping_time" "$speed_mb_s" "$speed_mbps"
}

get_network_speed() {
    box_section_header "🌐" "NETZWERK-GESCHWINDIGKEITSTEST (Weltweite Download-Knoten)"
    printf "${C_BORDER}│${C_RESET}  ${C_LABEL}%-27s${C_RESET} ${C_DIM}│${C_RESET} ${C_LABEL}%-12s${C_RESET} ${C_DIM}│${C_RESET} ${C_LABEL}%-14s${C_RESET} ${C_DIM}│${C_RESET} ${C_LABEL}%-12s${C_RESET}\n" \
           "Standort / Knoten" "Latenz" "Durchsatz" "Bitrate"
    echo -e "${C_BORDER}├─────────────────────────────┼──────────────┼────────────────┼──────────────┤${C_RESET}"

    # Deutschland & Europa
    test_single_node "🇩🇪" "Frankfurt (Hetzner)" "https://fsn1-speed.hetzner.com/100MB.bin" "4"
    test_single_node "🇩🇪" "Nürnberg (Hetzner)" "https://nbg1-speed.hetzner.com/100MB.bin" "4"
    test_single_node "🇩🇪" "Falkenstein (OVH)" "http://de.proof.ovh.net/files/100Mb.dat" "4"
    test_single_node "🇳🇱" "Amsterdam (Leaseweb)" "http://mirror.nl.leaseweb.net/speedtest/100mb.bin" "4"
    test_single_node "🇬🇧" "London (Linode)" "http://speedtest.london.linode.com/100MB-london.bin" "4"
    test_single_node "🇫🇷" "Paris (Scaleway)" "http://ping.online.net/100Mo.dat" "4"

    # Nordamerika
    test_single_node "🇺🇸" "New York (Linode)" "http://speedtest.newark.linode.com/100MB-newark.bin" "4"
    test_single_node "🇺🇸" "Dallas (Linode)" "http://speedtest.dallas.linode.com/100MB-dallas.bin" "4"
    test_single_node "🇺🇸" "San Francisco (DO)" "http://speedtest-sfo1.digitalocean.com/100mb.test" "4"

    # Asien & Ozeanien
    test_single_node "🇸🇬" "Singapur (Linode)" "http://speedtest.singapore.linode.com/100MB-singapore.bin" "4"
    test_single_node "🇯🇵" "Tokio (Linode)" "http://speedtest.tokyo2.linode.com/100MB-tokyo2.bin" "4"
    test_single_node "🇦🇺" "Sydney (Linode)" "http://speedtest.sydney1.linode.com/100MB-sydney.bin" "4"

    box_section_footer
}

# ==============================================================================
# 8. Professionelle Ergebnis-Bewertung
# ==============================================================================
generate_evaluation() {
    box_section_header "📊" "ERGEBNIS-BEWERTUNG & ANALYSE"

    # 1. Festplatten I/O
    local io_badge=""
    local io_desc=""
    if (( $(echo "$AVG_IO_NUM >= 1500" | bc -l 2>/dev/null || awk -v v="$AVG_IO_NUM" 'BEGIN{print (v>=1500)}') )); then
        io_badge="${C_GREEN}● EXZELLENT${C_RESET}"
        io_desc="${C_VALUE}${AVG_IO_NUM} MB/s${C_RESET} ${C_DIM}➜ High-End NVMe SSD (PCIe 4.0/5.0). Optimal für anspruchsvolle Datenbanken.${C_RESET}"
    elif (( $(echo "$AVG_IO_NUM >= 600" | bc -l 2>/dev/null || awk -v v="$AVG_IO_NUM" 'BEGIN{print (v>=600)}') )); then
        io_badge="${C_GREEN}● SEHR GUT${C_RESET}"
        io_desc="${C_VALUE}${AVG_IO_NUM} MB/s${C_RESET} ${C_DIM}➜ Schnelle NVMe SSD. Sehr gute Zugriffs- und Schreibzeiten.${C_RESET}"
    elif (( $(echo "$AVG_IO_NUM >= 200" | bc -l 2>/dev/null || awk -v v="$AVG_IO_NUM" 'BEGIN{print (v>=200)}') )); then
        io_badge="${C_YELLOW}● STANDARD${C_RESET}"
        io_desc="${C_VALUE}${AVG_IO_NUM} MB/s${C_RESET} ${C_DIM}➜ SATA SSD / Cloud-SSD. Ausreichend für Standard-Webserver & CMS.${C_RESET}"
    elif (( $(echo "$AVG_IO_NUM >= 70" | bc -l 2>/dev/null || awk -v v="$AVG_IO_NUM" 'BEGIN{print (v>=70)}') )); then
        io_badge="${C_YELLOW}▲ AKZEPTABEL${C_RESET}"
        io_desc="${C_VALUE}${AVG_IO_NUM} MB/s${C_RESET} ${C_DIM}➜ HDD oder gedrosselte Cloud-SSD. Bei hoher Last möglicher Engpass.${C_RESET}"
    elif (( $(echo "$AVG_IO_NUM > 0" | bc -l 2>/dev/null || awk -v v="$AVG_IO_NUM" 'BEGIN{print (v>0)}') )); then
        io_badge="${C_RED}✖ ZU LANGSAM${C_RESET}"
        io_desc="${C_VALUE}${AVG_IO_NUM} MB/s${C_RESET} ${C_RED}➜ Kritischer I/O-Flaschenhals! Shared-Storage überlastet oder alte HDD.${C_RESET}"
    else
        io_badge="${C_DIM}○ N/A${C_RESET}"
        io_desc="Kein I/O-Test durchgeführt"
    fi
    printf "${C_BORDER}│${C_RESET}  %-24s : %-16b %b\n" "Festplatten I/O" "$io_badge" "$io_desc"

    # 2. Netzwerk-Speed
    local net_badge=""
    local net_desc=""
    if (( $(echo "$PEAK_NET_MBPS >= 800" | bc -l 2>/dev/null || awk -v v="$PEAK_NET_MBPS" 'BEGIN{print (v>=800)}') )); then
        net_badge="${C_GREEN}● EXZELLENT${C_RESET}"
        net_desc="${C_VALUE}Peak ${PEAK_NET_MBPS} Mbps${C_RESET} ${C_DIM}➜ Volle 1 Gbit/s - 10 Gbit/s Anbindung ohne Drosselung.${C_RESET}"
    elif (( $(echo "$PEAK_NET_MBPS >= 400" | bc -l 2>/dev/null || awk -v v="$PEAK_NET_MBPS" 'BEGIN{print (v>=400)}') )); then
        net_badge="${C_GREEN}● SEHR GUT${C_RESET}"
        net_desc="${C_VALUE}Peak ${PEAK_NET_MBPS} Mbps${C_RESET} ${C_DIM}➜ Schnelle Gigabit-Anbindung für hohe Traffic-Volumina.${C_RESET}"
    elif (( $(echo "$PEAK_NET_MBPS >= 100" | bc -l 2>/dev/null || awk -v v="$PEAK_NET_MBPS" 'BEGIN{print (v>=100)}') )); then
        net_badge="${C_YELLOW}● BEFRIEDIGEND${C_RESET}"
        net_desc="${C_VALUE}Peak ${PEAK_NET_MBPS} Mbps${C_RESET} ${C_DIM}➜ Standard-VPS Anbindung (100–400 Mbps), solide für Webapps.${C_RESET}"
    elif (( $(echo "$PEAK_NET_MBPS > 0" | bc -l 2>/dev/null || awk -v v="$PEAK_NET_MBPS" 'BEGIN{print (v>0)}') )); then
        net_badge="${C_RED}✖ EINGESCHRÄNKT${C_RESET}"
        net_desc="${C_VALUE}Peak ${PEAK_NET_MBPS} Mbps${C_RESET} ${C_RED}➜ Geringe Bandbreite (< 100 Mbps) oder Hoster-Drosselung.${C_RESET}"
    else
        net_badge="${C_DIM}○ N/A${C_RESET}"
        net_desc="Kein Speedtest durchgeführt"
    fi
    printf "${C_BORDER}│${C_RESET}  %-24s : %-16b %b\n" "Netzwerkanbindung" "$net_badge" "$net_desc"

    # 3. CPU Krypto-Leistung
    local cpu_badge=""
    local cpu_desc=""
    if (( $(echo "$CPU_AES_NUM >= 2000" | bc -l 2>/dev/null || awk -v v="$CPU_AES_NUM" 'BEGIN{print (v>=2000)}') )); then
        cpu_badge="${C_GREEN}● TOP LEISTUNG${C_RESET}"
        cpu_desc="${C_VALUE}${CPU_AES_NUM} MB/s AES${C_RESET} ${C_DIM}➜ Moderne Server-CPU (EPYC/Xeon/Ryzen) mit starkem AES-NI.${C_RESET}"
    elif (( $(echo "$CPU_AES_NUM >= 800" | bc -l 2>/dev/null || awk -v v="$CPU_AES_NUM" 'BEGIN{print (v>=800)}') )); then
        cpu_badge="${C_GREEN}● GUT${C_RESET}"
        cpu_desc="${C_VALUE}${CPU_AES_NUM} MB/s AES${C_RESET} ${C_DIM}➜ Zeitgemäße CPU-Leistung mit funktionierender AES-Beschleunigung.${C_RESET}"
    elif (( $(echo "$CPU_AES_NUM > 0" | bc -l 2>/dev/null || awk -v v="$CPU_AES_NUM" 'BEGIN{print (v>0)}') )); then
        cpu_badge="${C_YELLOW}▲ MÄSSIG${C_RESET}"
        cpu_desc="${C_VALUE}${CPU_AES_NUM} MB/s AES${C_RESET} ${C_DIM}➜ Ältere CPU oder fehlende Host-Passthrough-Unterstützung.${C_RESET}"
    fi
    printf "${C_BORDER}│${C_RESET}  %-24s : %-16b %b\n" "CPU Krypto-Power" "$cpu_badge" "$cpu_desc"

    # 4. Cloudflare WARP & TCP BBR
    local warp_badge="${C_RED}○ INAKTIV${C_RESET}"
    local warp_desc="${C_DIM}Port 40000 ist nicht erreichbar / WARP nicht eingerichtet.${C_RESET}"
    if [ "$WARP_IS_OK" = true ]; then
        warp_badge="${C_GREEN}● BEREIT${C_RESET}"
        warp_desc="${C_DIM}WARP SOCKS5 Proxy auf Port 40000 aktiv und leitet Traffic über Cloudflare.${C_RESET}"
    fi
    printf "${C_BORDER}│${C_RESET}  %-24s : %-16b %b\n" "Cloudflare WARP (40000)" "$warp_badge" "$warp_desc"

    local bbr_badge="${C_YELLOW}▲ INAKTIV${C_RESET}"
    local bbr_desc="${C_DIM}Cubic/Reno aktiv. TCP BBR kann Durchsatz und Latenz spürbar optimieren.${C_RESET}"
    if [ "$IS_BBR" = true ]; then
        bbr_badge="${C_GREEN}● OPTIMAL${C_RESET}"
        bbr_desc="${C_DIM}BBR aktiv. Modernster TCP-Algorithmus für Spitzenübertragungen.${C_RESET}"
    fi
    printf "${C_BORDER}│${C_RESET}  %-24s : %-16b %b\n" "TCP BBR Optimierung" "$bbr_badge" "$bbr_desc"

    box_section_footer
}

# ==============================================================================
# 9. Optimierungs-Tipps & Empfehlungen
# ==============================================================================
generate_tips() {
    box_section_header "💡" "EMPFEHLUNGEN & OPTIMIERUNGS-TIPPS"
    local tip_count=0

    # Tipp 1: TCP BBR
    if [ "$IS_BBR" = false ]; then
        tip_count=$((tip_count + 1))
        echo -e "${C_BORDER}│${C_RESET}  ${C_ACCENT}[Tipp $tip_count] TCP BBR aktivieren (Erhöht Download-/Upload-Raten signifikant):${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}    ${C_WHITE}echo 'net.core.default_qdisc=fq' | sudo tee -a /etc/sysctl.conf${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}    ${C_WHITE}echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.conf${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}    ${C_WHITE}sudo sysctl -p${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}"
    fi

    # Tipp 2: Cloudflare WARP 40000
    if [ "$WARP_IS_OK" = false ]; then
        tip_count=$((tip_count + 1))
        echo -e "${C_BORDER}│${C_RESET}  ${C_ACCENT}[Tipp $tip_count] Cloudflare WARP Server auf Port 40000 einrichten (SOCKS5):${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}    ${C_WHITE}sudo apt install cloudflare-warp${C_RESET} ${C_DIM}# bzw. dnf/yum${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}    ${C_WHITE}warp-cli register && warp-cli set-mode proxy && warp-cli set-proxy-port 40000 && warp-cli connect${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}"
    fi

    # Tipp 3: CPU Host-Passthrough
    if [ "$HAS_AES" = false ]; then
        tip_count=$((tip_count + 1))
        echo -e "${C_BORDER}│${C_RESET}  ${C_ACCENT}[Tipp $tip_count] CPU Hardware-Befehlssätze aktivieren (AES-NI fehlt):${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}    ${C_DIM}Falls dieser Server in Proxmox/KVM läuft: Ändere den CPU-Typ auf ${C_RESET}${C_WHITE}'host'${C_RESET}${C_DIM}.${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}"
    fi

    # Tipp 4: SSD TRIM
    if (( $(echo "$AVG_IO_NUM < 600 && $AVG_IO_NUM > 0" | bc -l 2>/dev/null || awk -v v="$AVG_IO_NUM" 'BEGIN{print (v<600 && v>0)}') )); then
        tip_count=$((tip_count + 1))
        echo -e "${C_BORDER}│${C_RESET}  ${C_ACCENT}[Tipp $tip_count] SSD Wartung / TRIM aktivieren (Verhindert I/O-Performance-Verlust):${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}    ${C_WHITE}sudo systemctl enable --now fstrim.timer${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}"
    fi

    # Tipp 5: Speicherplatz
    if [ "$DISK_FULL_PERCENT" -ge 85 ]; then
        tip_count=$((tip_count + 1))
        echo -e "${C_BORDER}│${C_RESET}  ${C_RED}[Warnung] Speicherplatz zu ${DISK_FULL_PERCENT}% belegt:${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}    ${C_WHITE}sudo journalctl --vacuum-time=3d && sudo apt clean${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}"
    fi

    # Keine Tipps notwendig
    if [ "$tip_count" -eq 0 ]; then
        echo -e "${C_BORDER}│${C_RESET}  ${C_GREEN}✨ Hervorragend! Dein Server ist bereits optimal konfiguriert.${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}    ${C_DIM}✔ TCP BBR ist aktiv │ ✔ WARP 40000 läuft │ ✔ Schnelle I/O & Anbindung${C_RESET}"
    fi

    box_section_footer
}

# ==============================================================================
# Ausführlicher WARP-Diagnose-Modus (-w / --warp)
# ==============================================================================
get_warp_detailed_report() {
    box_section_header "🛡️" "CLOUDFLARE WARP DETAIL-DIAGNOSE (Port 40000)"

    local warp_cli_bin="${C_RED}Nicht gefunden${C_RESET}"
    if check_tool warp-cli; then
        warp_cli_bin="${C_GREEN}Installiert ($(warp-cli --version 2>/dev/null || echo "vorhanden"))${C_RESET}"
    fi

    local service_status="${C_RED}Inaktiv / Gestoppt${C_RESET}"
    if pgrep -f "warp-svc" >/dev/null 2>&1; then
        service_status="${C_GREEN}Aktiv (warp-svc Prozess läuft)${C_RESET}"
    elif check_tool systemctl && systemctl is-active --quiet warp-svc 2>/dev/null; then
        service_status="${C_GREEN}Aktiv (systemd)${C_RESET}"
    fi

    local port_status="${C_RED}Geschlossen / Nicht lauschend${C_RESET}"
    if (echo > /dev/tcp/127.0.0.1/40000) 2>/dev/null; then
        port_status="${C_GREEN}Geöffnet (127.0.0.1:40000 erreichbar)${C_RESET}"
    elif check_tool ss && ss -tulpn 2>/dev/null | grep -q ":40000"; then
        port_status="${C_GREEN}Geöffnet (ss zeigt Port 40000)${C_RESET}"
    fi

    box_row "warp-cli Client" "$warp_cli_bin"
    box_row "warp-svc Dienst" "$service_status"
    box_row "Port 40000 Status" "$port_status"

    if check_tool curl; then
        echo -e "${C_BORDER}│${C_RESET}  ${C_ACCENT}⏳ Prüfe Verbindung über SOCKS5 Proxy 127.0.0.1:40000...${C_RESET}"
        local trace_out
        trace_out=$(curl -s -m 5 --socks5-hostname 127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null)
        if [ -n "$trace_out" ]; then
            local w_ip=$(echo "$trace_out" | awk -F= '/^ip=/ {print $2}')
            local w_warp=$(echo "$trace_out" | awk -F= '/^warp=/ {print $2}')
            local w_loc=$(echo "$trace_out" | awk -F= '/^loc=/ {print $2}')
            local w_colo=$(echo "$trace_out" | awk -F= '/^colo=/ {print $2}')
            box_row "WARP IP-Adresse" "${C_CYAN}${w_ip}${C_RESET} (WARP-Status: ${C_GREEN}${w_warp}${C_RESET})"
            box_row "WARP Rechenzentrum" "${w_loc} │ Cloudflare Colo: ${w_colo}"
        else
            box_row "WARP CDN-Trace" "${C_RED}Fehlgeschlagen (Keine Rückmeldung über Port 40000)${C_RESET}"
        fi
    fi

    if check_tool warp-cli; then
        echo -e "${C_BORDER}│${C_RESET}"
        echo -e "${C_BORDER}│${C_RESET}  ${C_BOLD}warp-cli Status:${C_RESET}"
        warp-cli status 2>/dev/null | while read -r line; do
            echo -e "${C_BORDER}│${C_RESET}    ${C_DIM}${line}${C_RESET}"
        done || warp-cli --accept-tos status 2>/dev/null | while read -r line; do
            echo -e "${C_BORDER}│${C_RESET}    ${C_DIM}${line}${C_RESET}"
        done
    fi
    box_section_footer
}

# ==============================================================================
# Hilfe & Parameter-Verarbeitung
# ==============================================================================
show_help() {
    echo -e "${C_BOLD}Verwendung:${C_RESET} $0 [OPTION]"
    echo ""
    echo -e "${C_BOLD}Verfügbare Optionen:${C_RESET}"
    echo -e "  ${C_CYAN}-i,   --info${C_RESET}       Nur Hardware- & System-Informationen anzeigen"
    echo -e "  ${C_CYAN}-w,   --warp${C_RESET}       Ausführliche Cloudflare WARP (Port 40000) Diagnose"
    echo -e "  ${C_CYAN}-io,  --disk${C_RESET}       Nur Festplatten I/O Benchmark ausführen"
    echo -e "  ${C_CYAN}-c,   --cpu${C_RESET}        Nur CPU Krypto-Benchmark ausführen"
    echo -e "  ${C_CYAN}-net, --network${C_RESET}    Nur Netzwerk-Geschwindigkeitstest ausführen"
    echo -e "  ${C_CYAN}-h,   --help${C_RESET}       Diese Hilfe anzeigen"
    echo ""
    echo "Ohne Parameter wird der vollständige Benchmark ausgeführt"
    echo "inklusive erweiterter Hardware-Diagnose, Bewertung und Optimierungstipps."
    exit 0
}

# ==============================================================================
# Hauptprogramm
# ==============================================================================
main() {
    local opt="$1"

    case "$opt" in
        -i|--info)
            print_banner
            get_system_info
            get_cpu_details
            get_gpu_details
            get_storage_details
            ;;
        -w|--warp)
            print_banner
            get_warp_detailed_report
            ;;
        -io|--disk)
            print_banner
            get_disk_io
            ;;
        -c|--cpu)
            print_banner
            get_cpu_benchmark
            ;;
        -net|--network)
            print_banner
            get_network_speed
            ;;
        -h|--help)
            show_help
            ;;
        *)
            print_banner
            get_system_info
            get_cpu_details
            get_gpu_details
            get_storage_details
            get_disk_io
            get_cpu_benchmark
            get_network_speed
            generate_evaluation
            generate_tips
            ;;
    esac

    echo ""
    echo -e "${C_GREEN}${C_BOLD}  ✔ Benchmark & Hardware-Diagnose erfolgreich abgeschlossen!${C_RESET}"
    echo -e "${C_BORDER}════════════════════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "  ${C_DIM}GitHub Repository:${C_RESET} ${C_CYAN}https://github.com/kingcosta/bench${C_RESET}"
    echo ""
}

main "$@"
