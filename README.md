# 🚀 Linux Server Benchmark Skript (Deutsch & Europe/Berlin)

Ein modernes, schnelles und übersichtliches Linux Server Benchmark-Skript im Stil von **[bench.sh](https://bench.sh)** / **SuperBench** / **YABS** – vollständig auf **Deutsch**, mit **Europe/Berlin** Zeitzone und integrierter Prüfung auf einen laufenden **Cloudflare WARP Server (Port 40000)**.

---

## 📋 Features

- 🕒 **Zeitzone & Lokalisierung:**
  - Standardmäßig auf `Europe/Berlin` gesetzt (deutsche Datums- und Uhrzeitformate).
  - Alle Texte, Statusmeldungen und Labels sind vollständig auf Deutsch.

- 🛡️ **Cloudflare WARP (Port 40000) Überprüfung:**
  - Erkennt, ob `warp-cli` / `warp-svc` installiert ist.
  - Prüft, ob der Hintergrunddienst aktiv ist.
  - Prüft, ob **Port 40000** lokal geöffnet ist (SOCKS5 Proxy).
  - Führt einen echten Trace-Test über `127.0.0.1:40000` gegen Cloudflare durch und ermittelt WARP-Status (`warp=on`), WARP-IP und Standort.

- 🖥️ **Hardware & System-Informationen:**
  - CPU Modell, Kerne, Threads, Taktfrequenz & L1/L2/L3 Cache
  - Hardware AES-NI Unterstützung
  - Betriebssystem, Distribution & Architektur (`x86_64`, `aarch64` / ARM64)
  - Linux Kernel-Version
  - Virtualisierungs-Erkennung (KVM, Proxmox, VMware, Xen, OpenVZ, Docker oder Dedicated Baremetal)
  - RAM & SWAP Speicherverbrauch (Gesamt, Belegt, Verfügbar)
  - Festplattenplatz der Root-Partition & Dateisystem (ext4, btrfs, zfs, xfs etc.)
  - System Uptime & Load Average (1m, 5m, 15m)
  - TCP Congestion Control (z. B. BBR, Cubic)
  - Öffentliche IPv4 / IPv6 Adresse, ISP / Hoster, ASN und Geo-Standort (Stadt & Land)

- 💾 **Festplatten I/O Benchmark:**
  - 3 sequentielle Schreib-Durchläufe mit je 1 GB Blockgröße (`conv=fdatasync`)
  - Automatische Berechnung des Durchschnitts in MB/s

- ⚡ **CPU Performance Test:**
  - Integrierter OpenSSL SHA256 & AES-256-GCM Durchsatztest (Single-Thread)

- 🌐 **Netzwerk Speedtest & Latenz:**
  - Download-Speedtest & Ping-Messung zu weltweiten Rechenzentren (Deutschland, Europa, USA, Asien, Australien)
  - Ausgabe in **MB/s** und **Mbps**

---

## 📥 Ausführung

### Option 1: Als One-Liner ausführen

```bash
# Mit curl:
curl -sL https://deine-domain.tld/bench.sh | bash

# Mit wget:
wget -qO- https://deine-domain.tld/bench.sh | bash
```

### Option 2: Manuell starten

```bash
chmod +x bench.sh
./bench.sh
```

---

## ⚙️ Parameter / Optionen

| Parameter | Beschreibung |
|---|---|
| `./bench.sh` | Führt den vollständigen Benchmark inkl. Systeminfos, WARP-Check, I/O und Speedtest aus |
| `./bench.sh -i` / `--info` | Zeigt nur die System- und Hardware-Informationen (inkl. WARP-Status) |
| `./bench.sh -w` / `--warp` | Führt eine **ausführliche Detaildiagnose** für Cloudflare WARP auf Port 40000 durch |
| `./bench.sh -io` / `--disk` | Führt nur den Festplatten I/O Benchmark aus |
| `./bench.sh -c` / `--cpu` | Führt nur den CPU Krypto-Benchmark aus |
| `./bench.sh -net` / `--network` | Führt nur den Netzwerk-Speedtest aus |
| `./bench.sh -h` / `--help` | Zeigt die Hilfe-Übersicht an |

---

## 🖥️ Beispiel-Ausgabe

```text
======================================================================
                   LINUX SERVER BENCHMARK SKRIPT                     
                 System-Informationen & Performance-Test             
======================================================================
 Version: 1.1.0               Datum (Europe/Berlin): 30.09.2026 18:30:15 CEST
----------------------------------------------------------------------
 -> SYSTEM-INFORMATIONEN
----------------------------------------------------------------------
 CPU Modell              : AMD EPYC 7763 64-Core Processor
 CPU Konfiguration       : 4 Kerne / 4 Threads (@ 2445.39 MHz)
 CPU Cache & Features    : 512 KB | AES-NI: Aktiviert
 Betriebssystem          : Ubuntu 24.04 LTS (x86_64)
 Kernel-Version          : 6.8.0-31-generic
 Virtualisierung         : KVM
 Cloudflare WARP (40000) : Aktiv & Verbunden (Port 40000 SOCKS5 | WARP=on | IP: 104.28.xxx.xxx [DE])
 Arbeitsspeicher (RAM)   : 7.8Gi (Belegt: 1.2Gi | Verfügbar: 6.1Gi)
 Swap-Speicher           : 2.0Gi (Belegt: 0B)
 Festplattenspeicher (/) : 98G (Belegt: 14G [15%] | Dateisystem: ext4)
 Systemlaufzeit (Uptime) : up 12 days, 4 hours
 Lastdurchschnitt (Load) : 0.15, 0.22, 0.18
 TCP-Algorithmus (BBR)   : bbr
 Standort (GeoIP)        : Frankfurt, Germany
 Anbieter & ASN          : Hetzner Online GmbH / AS24940
 Öffentliche IPv4        : 159.69.xxx.xxx
 Öffentliche IPv6        : 2a01:4f8:xxx:xxx::1
----------------------------------------------------------------------
 -> FESTPLATTEN I/O GESCHWINDIGKEIT (Sequentieller Schreibtest)
----------------------------------------------------------------------
 1. Durchlauf (1 GB)     : 1.4 GB/s
 2. Durchlauf (1 GB)     : 1.5 GB/s
 3. Durchlauf (1 GB)     : 1.4 GB/s
 Durchschnittliche I/O   : 1466.67 MB/s
----------------------------------------------------------------------
 -> CPU-LEISTUNG (OpenSSL 3-Sekunden Krypto-Benchmark)
----------------------------------------------------------------------
 SHA256 (Single-Thread)  : 584.21 MB/s
 AES-256-GCM (Single)    : 1820.50 MB/s
----------------------------------------------------------------------
 -> NETZWERK-GESCHWINDIGKEITSTEST (Weltweite Download-Knoten)
----------------------------------------------------------------------
 Knoten / Standort         Latenz           Geschwindigkeit  Bitrate     
----------------------------------------------------------------------
 Frankfurt, DE (Hetzner)   1.20 ms          112.40 MB/s      899.20 Mbps 
 Nürnberg, DE (Hetzner)    4.50 ms          108.10 MB/s      864.80 Mbps 
 Falkenstein, DE (OVH)     5.10 ms          110.00 MB/s      880.00 Mbps 
 Amsterdam, NL (Leaseweb)  8.30 ms          105.50 MB/s      844.00 Mbps 
 London, UK (Linode)       14.20 ms         98.40 MB/s       787.20 Mbps 
 Paris, FR (Scaleway)      12.10 ms         95.00 MB/s       760.00 Mbps 
 New York, US (Linode)     78.40 ms         45.20 MB/s       361.60 Mbps 
 Dallas, US (Linode)       105.10 ms        32.10 MB/s       256.80 Mbps 
 Singapur, SG (Linode)     165.40 ms        18.40 MB/s       147.20 Mbps 
 Tokio, JP (Linode)        210.30 ms        14.10 MB/s       112.80 Mbps 
----------------------------------------------------------------------
 Benchmark erfolgreich abgeschlossen!
======================================================================
```
