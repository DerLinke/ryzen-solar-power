# ☀️ ryzen-solar-power

Ein intelligentes Installations- und Steuerungsskript zur Energieoptimierung von AMD Ryzen CPUs unter Debian/Ubuntu. Speziell entwickelt für den autarken Betrieb an Solar-Batterien und Powerbanks (z.B. im Garagen-Setup), um stromkritische Lastspitzen zu dämpfen und gleichzeitig maximale Gaming-Performance bei Bedarf zu gewährleisten.

## Features

- **Schutz vor Einschaltstromspitzen (Boot-Schutz):** Richtet einen extrem frühen systemd Boot-Service ein, der die CPU-Leistung (TDP) sofort auf 20W beschränkt, bevor stromintensive Services oder die Benutzeroberfläche laden.
- **Automatischer Garagen-Modus:** Setzt den CPU-Governor standardmäßig auf `powersave` und limitiert das Ryzen-Power-Limit (STAPM/PPT) auf **20 Watt**.
- **Dynamischer Spiele-Modus (GameMode):** Bindet sich in die lokalen Feral GameMode Hooks ein. Sobald ein Spiel über `gamemoderun` gestartet wird, wird das TDP-Limit vollständig aufgehoben (**54W/Max**) und der CPU-Governor wechselt zu `performance`.
- **cpufreq-set Kompatibilität:** Bietet einen Wrapper für Altsysteme, auf denen `cpufrequtils` nicht mehr verfügbar ist.

## Voraussetzungen

- Debian 12/13 oder ein darauf basierendes System (z.B. Linux Mint, Ubuntu)
- Eine kompatible AMD Ryzen CPU (Zen 1 bis Zen 4 / Hawk Point etc.)
- Benutzer mit passwortlosen Sudo-Rechten (`NOPASSWD: ALL` oder entsprechende Berechtigung für `ryzenadj` und `cpufreq-set`)

## Installation

Klone das Repository und führe das Installationsskript aus:

```bash
git clone https://github.com/DerLinke/ryzen-solar-power.git
cd ryzen-solar-power
./install.sh
```

## Verwendung & Verifikation

Nach der Installation läuft das System standardmäßig im **Garagen-Modus**.

### Modus manuell aktivieren

- **Garagen-Modus (TDP 20W, Powersave):**
  ```bash
  sudo garagen-modus.sh
  ```

- **Spiele-Modus (TDP Max/54W):**
  ```bash
  sudo spiele-modus.sh
  ```

### Status & TDP Limits prüfen

Du kannst die aktuellen Limits der CPU jederzeit mit folgendem Befehl auslesen:
```bash
sudo ryzenadj -i
```

Den Status des Boot-Schutz-Dienstes kannst du mit systemd prüfen:
```bash
systemctl status garagen-modus-boot.service
```

---
<p align="center">
  <img src="https://derlinke.github.io/logo.svg" width="300" alt="Logo"><br>
  <strong>DerLinke Software Zentrale</strong><br>
  <a href="https://derlinke.github.io/">Offizielle Webseite</a> | <a href="https://github.com/DerLinke/ryzen-solar-power">GitHub Repository</a>
</p>
