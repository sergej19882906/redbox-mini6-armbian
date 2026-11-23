# Armbian для Redbox Mini 6 (v1)

Сборка Armbian 26.8 (ветка 26.8.x ≈ релиз 26.8.3) для ТВ-приставки **Redbox Mini 6 (v1)** — белорусский
операторский бокс (A1/Velcom) на **Allwinner H6**, клон Tanix TX6.

Два варианта образов собираются автоматически в GitHub Actions:

| Вариант | Описание |
|---|---|
| `minimal` | Минимальный сервер (BUILD_MINIMAL=yes) |
| `lxqt` | Лёгкий десктоп LXQt |

В оба образа автоматически вживляется собственный DTB
`sun50i-h6-redbox-mini6.dtb` (вариант 1 ГБ RAM), `armbianEnv.txt`
дополнительно указывает `fdtfile`.

## Где взять образы

1. **Releases** репозитория — готовые `redbox-mini6-<variant>-run<N>.img.xz`
2. **Artifacts** запуска Actions — те же файлы

## Запись на флешку

```bash
xz -d redbox-mini6-minimal-YYYYMMDD.img.xz
sudo dd if=redbox-mini6-minimal-YYYYMMDD.img of=/dev/sdX bs=4M status=progress
```

(или Rufus/Etcher — они читают `.img` напрямую, xz-архив нужно распаковать)

## Загрузка

- Логин/пароль по умолчанию задаёт Armbian при первом старте
- Переключение вариантов DTB: `/boot/armbianEnv.txt` → `fdtfile=`
- Swap: `armbian-config` → System → Swap → zram (обязательно на 1 ГБ)
- Wi-Fi XR819 работает из ядра (`xradio`); Bluetooth — любой USB-донгл (`btusb`)
- Ethernet: только на ядрах с поддержкой AC200 (в mainline нет)

## Файлы

- `dts/sun50i-h6-redbox-mini6.dts` — исходник DT (база: Tanix TX6)
- `dtb/sun50i-h6-redbox-mini6.dtb` — скомпилированный DTB (1 ГБ RAM)
- `scripts/inject-dtb.sh` — вживление DTB в готовый `.img`
- `.github/workflows/armbian.yml` — сборка двух образов

## Сборка своего DTB из исходников

```bash
git clone --depth=1 --filter=blob:none --sparse https://github.com/torvalds/linux
cd linux && git sparse-checkout set arch/arm64/boot/dts/allwinner include/dt-bindings
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
  -I arch/arm64/boot/dts/allwinner -I include \
  dts/sun50i-h6-redbox-mini6.dts -o /tmp/rb6-pre.dts
dtc -I dts -O dtb -o sun50i-h6-redbox-mini6.dtb /tmp/rb6-pre.dts
```
