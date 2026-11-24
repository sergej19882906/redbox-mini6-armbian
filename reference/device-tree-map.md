# Дерево устройств Redbox Mini 6 (v1)

Полное устройство бокса Allwinner H6 с сопоставлением нативных BSP-узлов
(A1/velcom Android) и mainline-дерева, на котором собран
`dtb/sun50i-h6-redbox-mini6.dtb` (Armbian / LibreELEC).

## Источники

| Источник | Прошивка | Ядро | ● машина (BSP) |
|---|---|---|---|
| `reference/sun50iw6p1-petrelp1-velcom-20251124.dts` | velcom/A1 Android 7.1 OTA 2025-11 | 3.10.65 | `petrel-p1` |
| `reference/sun50iw6p1-redbox6-a9-20250926.dts` | Авторский A9 для Redbox, 2025-09 | 4.9.118 | `redbox-6-axpdummy` |
| `reference/sun50iw6p1-pendoox6-aosp-2.1.19.dts` | Pendoo X6 PRO AOSP 2.1.19 (2022) | 4.9.118 | `petrel-p1-axpdummy` |
| `reference/sun50iw6p1-a9-base-mx10axpdummy.dts` | Авторский A9 base | 4.9.x | `mx10-axpdummy` |
| `dts/sun50i-h6-redbox-mini6.dts` | Наш (mainline) | 6.18 | — |

Все четыре нативных BSP независимо подтверждают одинаковый AC200/EMAC/
wlan-конфиг — наш mainline-DTB ему точно соответствует.

## Иерархия (сокращённая)

```
/ (Redbox Mini 6 (v1), 1 GB DDR3 @ 0x40000000)
├── cpus / opp — 4× Cortex-A53 1.8 ГГц (sun50i-h6-cpu-opp.dtsi)
├── soc@0
│   ├── clock@3001000    ccu                      mainline
│   ├── syscon@3000000   system control           mainline
│   ├── watchdog@30090a0
│   ├── ir@7040000       sunxi-ir (пульт)         "allwinner,sun50i-h6-ir"
│   ├── dma-controller@3002000
│   ├── crypto@3041000
│   ├── mmc0@4020000     SD-карта (rootfs)
│   ├── mmc1@4021000     XR819 wifi, SDIO
│   │                    (BSP: wlan_busnum=1, regon PL3, hostwake PL0)
│   ├── mmc2@4022000     eMMC
│   ├── emac@6540000     EMAC + mdio → AC200 EPHY
│   │                    (BSP: eth@05020000, allwinner,sunxi-gmac,
│   │                     phy-mode=rmii, tx/rx-delay=0, vcc-ephy)
│   ├── i2c0@5002000 … i2c3@5002c00
│   │                    i2c3 → AC200 @ 0x10 (BSP: twi_id=3, twi_addr=0x10)
│   ├── usb@5100000, ehci@5110000/5311000, ohci@5200000… — оба USB-порта
│   │                    (USB-BT dongle работает через btusb)
│   ├── hdmi@6000000     dw-hdmi (видео + звук по HDMI)
│   ├── tcon-top, tcon-tv
│   ├── gpu@1800000      Mali-T720 MP2 → panfrost
│   ├── video-codec@1c0e000     cedrus (H.264, MPEG…)
│   ├── video-codec-g2@1c00000  cedrus-g2 (HEVC, VP9)
│   │                           (оба — V4L2 M2M, ffmpeg/mpv через v4l2request)
│   ├── pwm@300a000      канал 1 = 24 МГц часы для AC200
│   ├── spdif@5093000, i2s / codec-узлы
│   └── serial@5000000   UART-консоль ttyS0 115200 (отладка)
└──
```

## Ключевые сопоставления

| Подсистема | BSP (нативный A1) | mainline (наш DTB) | Статус |
|---|---|---|---|
| SoC | `sun50iw6p1` | `sun50i-h6` (совместимо) | ✅ |
| Плата | `petrel-p1` / `redbox-6-axpdummy` | `redbox,mini6-v1` | ✅ свои строки |
| Память | 512 МБ в BSP (uboot подтягивает фактический объём, `dram_region_mbytes=0x50`) | 1 ГБ явно (`0x40000000..0x7FFFFFFF`) | ✅ |
| EMAC | `eth@05020000`, `allwinner,sunxi-gmac`, rmii, delays 0, `vcc-ephy` | `emac@6540000` + mdio/phy (AC200 EPHY через I2C3) | ✅ совпадает |
| AC200 | twi_id=3, twi_addr=0x10, pwm_ch=1, ccir_clk PB0 | `ac200_pwm_clk` (pwm-clock 24 МГц, канал 1) + AC200 под i2c3 @ 0x10 | ✅ совпадает 4× независимо |
| Wi-Fi | `sunxi-wlan`, busnum 1, regon PL3, hostwake PL0 | `mmc1@4021000` SDIO (XR819 — out-of-tree драйвер) | ✅ |
| BT | в стоке подключается с USB-свистка (`btusb`) | btusb, DTB не требует изменений | ✅ |
| IR | sunxi-remote | `ir@7040000` sunxi-ir + rc-core | ✅ |
| eMMC | mmc2, drive-strength 0x03 | `mmc2@4022000` + non-removable | ✅ |
| USB | BSP usb-host, оба порта | ehci/ohci + хаб | ✅ |
| Видео | BSP proprietary (cedar) | cedrus (V4L2-request), патченный ffmpeg/mpv, KODI в LE | ✅ образы адаптированы |
| GPU | BSP Mali-T720 blob | panfrost (mainline) | ✅ LXQt/Kodi рисует |
| Звук | HDMI + внутренний codec | dw-hdmi-audio + sun4i-i2s/codec | ✅ |

## Отличия BSP → mainline

1. **Нет `axpdummy` PMIC**: BSP-деревья `*-axpdummy` описывают питание
   (regulator3-7) заглушками. В mainline питание описывается как и у
   Tanix TX6 — фиксированные regulator-fixed из `sun50i-h6-tanix.dtsi`
   (vcc1v8 / vcc3v3); инициализацию силовых цепей выполняет u-boot.
2. **vdevice/uart0** — виртуальный отладочный узел BSP, в mainline не нужен.
3. **TV/CAM-шины i2c2/twi2** у BSP — cam/tv; в mainline их не трогаем.
4. **Внутренний PHY**: BSP адресует его как `gmac-power0 = "vcc-ephy"`;
   в mainline используется драйвер AC200 EPHY (`ac200` + PWM1-часы), потому
   что физический PHY сидит на I2C3 внутри AC200.

## Сборка

```
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
    -I <kernel_tree>/arch/arm64/boot/dts/allwinner \
    -I <kernel_tree>/include \
    dts/sun50i-h6-redbox-mini6.dts -o /tmp/rb6-pre.dts
dtc -I dts -O dtb -o dtb/sun50i-h6-redbox-mini6.dtb /tmp/rb6-pre.dts
```

Проверено dtc: 25 088 Б; предупреждения только косметические
(unit_address_vs_reg — наследие стилистики BSP).
