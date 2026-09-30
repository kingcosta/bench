# 🚀 Linux Server Benchmark Skript (Deutsch & Europe/Berlin)

Ein modernes, schnelles und hardware-fokussiertes Linux Server Benchmark-Skript im Stil von **[bench.sh](https://bench.sh)** / **SuperBench** / **YABS** – vollständig auf **Deutsch**, mit **Europe/Berlin** Zeitzone, **tiefgehender Hardware-Diagnose (CPU, GPU, RAM, Mainboard & NVMe/Disks)**, Prüfung auf einen laufenden **Cloudflare WARP Server (Port 40000)** sowie automatischer **Ergebnis-Bewertung** und **Optimierungs-Tipps**.

---

## 📋 Features & Detaillierte Hardware-Analyse

### 🖥️ 1. System & Mainboard
- Systemhersteller & Produktmodell (z. B. Dell PowerEdge, HP ProLiant, Hetzner Server, QEMU Standard PC)
- Mainboard-Bezeichnung, BIOS-Version & Release-Datum
- Virtualisierungs-Erkennung (KVM, Proxmox, VMware ESXi, Xen, OpenVZ, Docker oder Dedicated Baremetal)
- Betriebssystem, Distribution & Architektur (`x86_64`, `aarch64` / ARM64)
- Linux Kernel-Version, Uptime, Lastdurchschnitt (1/5/15m) & TCP Algorithmus (BBR)
- IPv4/IPv6, GeoIP Standort (Stadt, Land), ISP & AS-Nummer

### ⚡ 2. Detaillierte Prozessor-Analyse (CPU)
- CPU Modell & Hersteller (AMD EPYC/Ryzen, Intel Xeon/Core, Ampere Altra)
- Exakte Topologie: Anzahl Sockets, physische Kerne und logische Threads
- Taktfrequenzen: Aktuelle Taktung, Min- und Max-Boost-MHz
- CPU Frequency Scaling Governor & Treiber (`performance`, `powersave`, `intel_pstate`, etc.)
- Cache-Hierarchie: L1d, L1i, L2 und L3 Cache-Größen
- Hardware-Befehlssätze & Features: **AES-NI**, **AVX**, **AVX2**, **AVX-512**, **VT-x / AMD-V**, **SSE4.2**

### 🎮 3. Grafikkarte & Beschleuniger (GPU)
- **NVIDIA GPU-Erkennung:** Modellname, GPU-Anzahl, VRAM (Gesamt/Belegt in MB), Treiber-Version, CUDA-Version, Temperatur (°C) & Leistungsaufnahme (Watt)
- **AMD & Intel GPU-Erkennung:** AMD Radeon / Instinct via `rocm-smi`, Intel Arc / UHD / Iris Graphics via `lspci`
- Saubere Fallback-Meldung bei Headless-Servern ohne dedizierte GPU

### 💾 4. Speicher & Laufwerke (RAM & Storage)
- **Arbeitsspeicher (RAM):** Gesamtkapazität, belegter und verfügbarer Speicher, RAM-Typ & Takt (z. B. DDR4/DDR5 @ 4800 MT/s, ECC)
- **Swap & ZRAM:** Speichergröße, Nutzung & ZRAM-Erkennung
- **Datenträger-Erkennung:** Auflistung aller physischen Laufwerke mit Modellbezeichnung, Speicherkapazität und Bus-Typ (NVMe, SATA, SAS, VirtIO)
- **Root-Partition:** Belegung, Dateisystem (ext4, zfs, btrfs, xfs) & aktiver I/O-Scheduler (`none`, `mq-deadline`, `bfq`, `kyber`)

### 🚀 5. Performance-Tests & Speedtest
- **Festplatten I/O Benchmark:** 3 sequentielle Schreib-Durchläufe mit je 1 GB (`conv=fdatasync`) und Durchschnittsberechnung
- **CPU Krypto-Benchmark:** OpenSSL SHA256 & AES-256-GCM Durchsatz (Single-Thread)
- **Netzwerk Speedtest & Latenz:** Download-Speedtest & Ping-Messung zu weltweiten Rechenzentren (Deutschland, Europa, USA, Asien, Australien) in **MB/s** und **Mbps** mit Länderflaggen

### 📊 6. Bewertung & Optimierungs-Tipps
- Automatische Einstufung der erreichten Werte (Exzellent, Sehr Gut, Standard, Zu Langsam)
- Direkte Befehle für **TCP BBR Tuning**, **Cloudflare WARP 40000 Setup**, **SSD TRIM**, **CPU Host-Passthrough** und Bereinigung

---

## 📥 Ausführung

### Option 1: Als One-Liner direkt ausführen

Einfach den folgenden Befehl im Terminal deines Linux-Servers eingeben:

```bash
# Mit curl:
curl -sL https://raw.githubusercontent.com/kingcosta/bench/main/bench.sh | bash

# Oder mit wget:
wget -qO- https://raw.githubusercontent.com/kingcosta/bench/main/bench.sh | bash
```

**One-Liner mit Parametern übergeben (z. B. nur Hardware-Info oder nur WARP-Test):**
```bash
# Nur Hardware- & System-Informationen:
curl -sL https://raw.githubusercontent.com/kingcosta/bench/main/bench.sh | bash -s -- -i

# Nur Cloudflare WARP 40000 Diagnose:
curl -sL https://raw.githubusercontent.com/kingcosta/bench/main/bench.sh | bash -s -- -w

# Nur Festplatten I/O Test:
curl -sL https://raw.githubusercontent.com/kingcosta/bench/main/bench.sh | bash -s -- -io
```

---

### Option 2: Über Git klonen und ausführen

```bash
git clone https://github.com/kingcosta/bench.git
cd bench
chmod +x bench.sh
./bench.sh
```

---

## ⚙️ Parameter / Optionen

| Parameter | Beschreibung |
|---|---|
| `./bench.sh` | Führt die vollständige Hardware-Analyse, WARP-Check, I/O, Speedtest, **Bewertung** und **Tipps** aus |
| `./bench.sh -i` / `--info` | Zeigt nur die Hardware- & System-Spezifikationen (CPU, GPU, RAM, Disks, WARP) |
| `./bench.sh -w` / `--warp` | Führt eine **ausführliche Detaildiagnose** für Cloudflare WARP auf Port 40000 durch |
| `./bench.sh -io` / `--disk` | Führt nur den Festplatten I/O Benchmark aus |
| `./bench.sh -c` / `--cpu` | Führt nur den CPU Krypto-Benchmark aus |
| `./bench.sh -net` / `--network` | Führt nur den Netzwerk-Speedtest aus |
| `./bench.sh -h` / `--help` | Zeigt die Hilfe-Übersicht an |

---

## 🖥️ Vorschau der Terminal-Ausgabe

```text
╭────────────────────────────────────────────────────────────────────────────╮
│  ██████╗ ███████╗███╗   ██╗ ██████╗██╗  ██╗   ██████╗ ██╗   ██╗            │
│  ██╔══██╗██╔════╝████╗  ██║██╔════╝██║  ██║   ██╔══██╗╚██╗ ██╔╝            │
│  ██████╔╝█████╗  ██╔██╗ ██║██║     ███████║   ██████╔╝ ╚████╔╝             │
│  ██╔══██╗██╔══╝  ██║╚██╗██║██║     ██╔══██║   ██╔══██╗  ╚██╔╝              │
│  ██████╔╝███████╗██║ ╚████║╚██████╗██║  ██║██╗██████╔╝   ██║               │
│  ╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═════╝    ╚═╝               │
│                                                                            │
│             ██████╗  ██████╗  ███████╗ ████████╗  █████╗                   │
│            ██╔════╝ ██╔═══██╗ ██╔════╝ ╚══██╔══╝ ██╔══██╗                  │
│            ██║      ██║   ██║ ███████╗    ██║    ███████║                  │
│            ██║      ██║   ██║ ╚════██║    ██║    ██╔══██║                  │
│            ╚██████╗ ╚██████╔╝ ███████║    ██║    ██║  ██║                  │
│             ╚═════╝  ╚═════╝  ╚══════╝    ╚═╝    ╚═╝  ╚═╝                  │
│                                                                            │
│   🚀 Detaillierter Server & Hardware Benchmark mit WARP Audit               │
│   📅 30.09.2026 18:35:10 CEST  │  🌐 Europe/Berlin  │  📦 v1.4.0           │
╰────────────────────────────────────────────────────────────────────────────╯

┌─[ 🖥️  SYSTEM & MAINBOARD SPEZIFIKATIONEN ────────────────────────────────┐
│  System / Plattform       : Hetzner Dedicated Server AX101
│  Mainboard & BIOS         : ASUSTeK ProArt B650-CREATOR (BIOS: 1414 vom 05/22/2024)
│  Virtualisierung          : Dedicated / Baremetal (Physischer Server)
│  Betriebssystem           : Ubuntu 24.04 LTS (x86_64)
│  Kernel-Version           : 6.8.0-31-generic
│  Cloudflare WARP (40000)  : ● AKTIV [Port 40000 SOCKS5] WARP=on ➜ IP: 104.28.xxx.xxx (DE)
│  Systemlaufzeit           : 18 days, 6 hours
│  Lastdurchschnitt (Load)  : 0.24, 0.31, 0.28
│  TCP Algorithmus          : bbr (Optimiert für Speed & Latenz)
│  Standort (GeoIP)         : Frankfurt, Germany
│  ISP & AS-Nummer          : Hetzner Online GmbH (AS24940)
│  Öffentliche IPv4         : 159.69.xxx.xxx
│  Öffentliche IPv6         : 2a01:4f8:xxx:xxx::1
└──────────────────────────────────────────────────────────────────────────┘

┌─[ ⚡  PROZESSOR (CPU) DETAIL-ANALYSE ────────────────────────────────────┐
│  CPU Modell               : AMD Ryzen 9 7950X 16-Core Processor
│  Hersteller / Vendor      : AuthenticAMD
│  Topologie                : 1 Socket(s) │ 16 Kerne │ 32 Threads
│  Taktfrequenz             : 4500.0 MHz (Min: 3000.0 MHz │ Max: 5700.0 MHz)
│  CPU Governor             : performance [amd-pstate-epp]
│  Cache-Größen             : L1d: 512 KiB │ L2: 16 MiB │ L3: 64 MiB
│  Instruktions-Sets        : AES-NI │ AVX-512 │ VT-x/AMD-V (Virtualisierung) │ SSE4.2
└──────────────────────────────────────────────────────────────────────────┘

┌─[ 🎮  GRAFIKKARTE (GPU) & BESCHLEUNIGER ─────────────────────────────────┐
│  NVIDIA GPU Modell        : NVIDIA GeForce RTX 4090 (Anzahl: 1)
│  VRAM Speicher            : 24564 MB GDDR6X
│  Treiber & CUDA           : Treiber: 550.54.14 │ CUDA: 12.4
│  Status & Temperatur      : 38 °C │ Leistungsaufnahme: 26.4 W
└──────────────────────────────────────────────────────────────────────────┘

┌─[ 💾  SPEICHER & LAUFWERKE (RAM & STORAGE) ──────────────────────────────┐
│  Arbeitsspeicher (RAM)    : 128Gi (Belegt: 18.4Gi │ Frei: 107.2Gi) [DDR5 @ 4800 MT/s]
│  Swap-Speicher            : 32.0Gi (Belegt: 0B) [ZRAM aktiv]
│  Root Partition (/)       : 1.8T (Belegt: 142G [8%] │ Frei: 1.6T │ Dateisystem: ext4)
│  I/O Scheduler            : none
│  Erkannte Laufwerke       :
│    • nvme0n1 (1.9T, NVME │ Samsung SSD 990 PRO 2TB)
│    • nvme1n1 (1.9T, NVME │ Samsung SSD 990 PRO 2TB)
└──────────────────────────────────────────────────────────────────────────┘

┌─[ 🚀  FESTPLATTEN I/O LEISTUNG (Sequentieller Schreibtest) ──────────────┐
│  1. Durchlauf (1 GB)      : 2.1 GB/s
│  2. Durchlauf (1 GB)      : 2.2 GB/s
│  3. Durchlauf (1 GB)      : 2.1 GB/s
│  Durchschnittliche I/O    : 2150.40 MB/s
└──────────────────────────────────────────────────────────────────────────┘

┌─[ ⚡  CPU KRYPTO-PERFORMANCE (OpenSSL Benchmark) ────────────────────────┐
│  SHA256 (Single-Thread)   : 1420.10 MB/s
│  AES-256-GCM (Single)     : 3850.80 MB/s
└──────────────────────────────────────────────────────────────────────────┘

┌─[ 🌐  NETZWERK-GESCHWINDIGKEITSTEST (Weltweite Download-Knoten) ─────────┐
│  Standort / Knoten           │ Latenz       │ Durchsatz      │ Bitrate     
├─────────────────────────────┼──────────────┼────────────────┼──────────────┤
│  🇩🇪 Frankfurt (Hetzner)     │ 0.80 ms      │ 118.20 MB/s    │ 945.60 Mbps 
│  🇩🇪 Nürnberg (Hetzner)      │ 3.20 ms      │ 115.10 MB/s    │ 920.80 Mbps 
│  🇩🇪 Falkenstein (OVH)       │ 4.50 ms      │ 112.00 MB/s    │ 896.00 Mbps 
│  🇳🇱 Amsterdam (Leaseweb)    │ 7.80 ms      │ 109.50 MB/s    │ 876.00 Mbps 
│  🇬🇧 London (Linode)         │ 13.50 ms     │ 102.40 MB/s    │ 819.20 Mbps 
│  🇫🇷 Paris (Scaleway)        │ 11.80 ms     │ 98.00 MB/s     │ 784.00 Mbps 
│  🇺🇸 New York (Linode)       │ 76.20 ms     │ 52.20 MB/s     │ 417.60 Mbps 
│  🇺🇸 Dallas (Linode)         │ 102.10 ms    │ 36.10 MB/s     │ 288.80 Mbps 
│  🇸🇬 Singapur (Linode)       │ 162.40 ms    │ 22.40 MB/s     │ 179.20 Mbps 
│  🇯🇵 Tokio (Linode)          │ 205.30 ms    │ 16.10 MB/s     │ 128.80 Mbps 
└──────────────────────────────────────────────────────────────────────────┘

┌─[ 📊  ERGEBNIS-BEWERTUNG & ANALYSE ──────────────────────────────────────┐
│  Festplatten I/O          : ● EXZELLENT      2150.40 MB/s ➜ High-End NVMe SSD (PCIe 4.0/5.0). Optimal für anspruchsvolle Datenbanken.
│  Netzwerkanbindung        : ● EXZELLENT      Peak 945.60 Mbps ➜ Volle 1 Gbit/s - 10 Gbit/s Anbindung ohne Drosselung.
│  CPU Krypto-Power         : ● TOP LEISTUNG   3850.80 MB/s AES ➜ Moderne Server-CPU (EPYC/Xeon/Ryzen) mit starkem AES-NI.
│  Cloudflare WARP (40000)  : ● BEREIT         WARP SOCKS5 Proxy auf Port 40000 aktiv und leitet Traffic über Cloudflare.
│  TCP BBR Optimierung      : ● OPTIMAL        BBR aktiv. Modernster TCP-Algorithmus für Spitzenübertragungen.
└──────────────────────────────────────────────────────────────────────────┘

┌─[ 💡  EMPFEHLUNGEN & OPTIMIERUNGS-TIPPS ─────────────────────────────────┐
│  ✨ Hervorragend! Dein Server ist bereits optimal konfiguriert.
│    ✔ TCP BBR ist aktiv │ ✔ WARP 40000 läuft │ ✔ Schnelle I/O & Anbindung
└──────────────────────────────────────────────────────────────────────────┘

  ✔ Benchmark & Hardware-Diagnose erfolgreich abgeschlossen!
════════════════════════════════════════════════════════════════════════════
  GitHub Repository: https://github.com/kingcosta/bench
```
