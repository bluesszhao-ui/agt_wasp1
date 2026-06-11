# wasp1 Memory Map

## 1. Initial Address Map

| Region | Base | Size | Cacheable | Executable | Notes |
| --- | ---: | ---: | --- | --- | --- |
| OTP data | `0x0000_0000` | `OTP_DATA_SIZE` | I-cache only | Yes | Main non-volatile program storage |
| OTP registers | `OTP_REG_BASE` | `0x0000_0100` | No | No | OTP programming/status control |
| I-SRAM | `0x1000_0000` | TBD | Yes | Yes | Fast code, loader, OTP program routines |
| D-SRAM | `0x2000_0000` | TBD | Yes or uncached window | Optional | Data, heap, stack, DMA buffers |
| DMA regs | `0x4000_0000` | `0x1000` | No | No | DMA configuration and status |
| WDG | `0x4001_0000` | `0x1000` | No | No | Watchdog |
| timer | `0x4002_0000` | `0x1000` | No | No | Machine timer |
| intc | `0x4003_0000` | `0x1000` | No | No | plic-lite external interrupt controller |
| UART | `0x4004_0000` | `0x1000` | No | No | UART |
| I2C | `0x4005_0000` | `0x1000` | No | No | I2C master |
| GPIO | `0x4006_0000` | `0x1000` | No | No | GPIO |

All unmapped addresses are handled by the AHB default slave and return an error
response.

## 2. Reset Vector

```text
reset_pc = 0x0000_0000
```

The reset vector points to OTP.

## 3. Cache Policy

| Region | I-cache | D-cache |
| --- | --- | --- |
| OTP | Cacheable for instruction fetch | Uncached for programming registers |
| I-SRAM | Cacheable | Cacheable |
| D-SRAM | Optional executable fetch | Cacheable or uncached software region |
| Peripherals | Uncached | Uncached |

## 4. Linker Layout

| Section | Load memory | Run memory |
| --- | --- | --- |
| `.text` | OTP | OTP |
| `.rodata` | OTP | OTP |
| `.fasttext` | OTP | I-SRAM |
| `.data` | OTP | D-SRAM |
| `.bss` | None | D-SRAM |
| `.heap` | None | D-SRAM |
| `.stack` | None | D-SRAM |

## 5. Open Items

Final sizes must be confirmed before RTL parameter freeze:

```text
OTP size
I-SRAM size
D-SRAM size
cache size
DMA maximum transfer size
GPIO width
UART FIFO depth
```
