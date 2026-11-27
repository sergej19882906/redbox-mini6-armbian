# Образы для TV-приставки Redbox Mini 6 (v1)

Готовые образы для **Redbox Mini 6 (v1)** — операторской приставки A1/Velcom (Беларусь)
на **Allwinner H6**, железного клона Tanix TX6. Вариант **1 ГБ RAM**.

Все образы собираются в GitHub Actions; внутрь каждого внедряется собственный DTB
`sun50i-h6-redbox-mini6.dtb`.

## Варианты образов

| Образ | Что внутри | Размер (сжат.) |
|---|---|---|
| `redbox-mini6-minimal-*.img.xz` | Armbian 26.8, минимальный сервер, ядро 6.18.40 + **mpv с аппаратным декодированием** (v4l2-request) | ~430 МБ |
| `redbox-mini6-lxqt-*.img.xz` | То же + рабочий стол **LXQt** | ~910 МБ |
| `libreelec-redbox-mini6-*.img.xz` | LibreELEC 12.95 (Kodi), устройство tanix-tx6 | ~180 МБ |


Armbian собирается из [armbian/build](https://github.com/armbian/build), тег `v26.8.0-trunk.424`,
ядро запинено `KERNELBRANCH=tag:v6.18.40`; драйвер AC200 содержится в патчах Armbian.
LibreELEC — из [LibreELEC/LibreELEC.tv](https://github.com/LibreELEC/LibreELEC.tv), тег `12.95.1`.

## Откуда скачать

**[Релиз v1.0](https://github.com/sergej19882906/redbox-mini6-armbian/releases/tag/v1.0)**:
- `redbox-mini6-minimal-20261125.img.xz` (432 МБ) + `.sha256`
- **`redbox-mini6-lxqt-20261127.img.xz` (946 МБ) — актуальный, с предустановленным mpv** (v4l2-request) + `.sha256`
- `redbox-mini6-lxqt-20261124.img.xz` (909 МБ) — первая сборка, без предустановленного mpv + `.sha256`
- `libreelec-redbox-mini6-20261124.img.xz` (176 МБ) + `.sha256`
- `mpv-v4l2req.tar.gz` — mpv с аппаратным декодированием отдельным архивом (для ручной установки в любой Armbian: `tar xzf mpv-v4l2req.tar.gz -C /`)

Новые сборки прикладываются к этому же релизу (`--clobber` по имени).

## Запись на флешку

```bash
xz -d redbox-mini6-minimal-*.img.xz
sudo dd if=redbox-mini6-minimal-*.img of=/dev/sdX bs=4M status=progress
```

(или Rufus/Etcher — для них `.xz` сначала нужно распаковать)

## Что работает

- **Wi-Fi** XR819 — из ядра (`xradio`)
- **Bluetooth** — любой USB-донгл (`btusb`), в Armbian и LibreELEC работает «из коробки»
- **Ethernet** (EMAC + AC200 ePHY) — в Armbian и LibreELEC (драйвер AC200 есть в обоих ядрах)
- **Видео/аудио** в LibreELEC — аппаратное (CedarX); в Armbian — **mpv + v4l2-request** (cedrus, `vo=gpu-next`) в minimal-образе

## Настройки после загрузки (Armbian)

- Логин `root` / пароль задаётся при первом старте
- **Swap**: `armbian-config` → System → Swap → **zram** — обязательно на 1 ГБ RAM
- Смена DTB: `/boot/armbianEnv.txt` → строка `fdtfile=`

## ⚠️ Про A1-приставки

- Родная прошивка A1 (h6-velcom-20220711) хранится в eMMC; запись образа **на SD-карту** её не трогает
- Никогда не ставьте OTA-обновления от прошивок других операторов

## Файлы репозитория

- `dts/sun50i-h6-redbox-mini6.dts` — исходник Device Tree (база Tanix TX6): 1 ГБ RAM + Ethernet AC200
- `dtb/sun50i-h6-redbox-mini6.dtb` — скомпилированный DTB (25 КБ)
- `scripts/inject-dtb.sh` — внедрение DTB в готовый Armbian-образ
- `scripts/inject-le-dtb.sh` — внедрение DTB в LibreELEC-образ
- `.github/workflows/armbian.yml` — сборка всех трёх образов (cron-дозор каждые 2 ч: доводит до релиза недостающее, лишнее пропускает гейтом)

## Как пересобрать

1. **GitHub Actions**: вкладка *Actions* → *Armbian + LibreELEC for Redbox Mini 6 (v1)* → **Run workflow**;
   готовые `.img.xz` появятся в **Artifacts** запуска
2. **Локально**: команды те же, что в workflow; сборка занимает 1–3 часа

## Сборка DTB из исходников

```bash
git clone --depth=1 --filter=blob:none --sparse https://github.com/torvalds/linux
cd linux && git sparse-checkout set arch/arm64/boot/dts/allwinner include/dt-bindings
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
  -I arch/arm64/boot/dts/allwinner -I include \
  ../dts/sun50i-h6-redbox-mini6.dts -o /tmp/rb6-pre.dts
dtc -I dts -O dtb -o sun50i-h6-redbox-mini6.dtb /tmp/rb6-pre.dts
```
