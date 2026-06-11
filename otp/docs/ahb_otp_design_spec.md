# ahb_otp Design Spec

## 1. Scope

`ahb_otp` is the executable OTP AHB-Lite slave for wasp1.

The lower part of the address range is a read-only executable OTP data window.
The upper 256 bytes are a control register window used by CPU software to
program OTP contents.

## 2. Block Diagram

```text
              hclk_i / hresetn_i
                      |
                      v
 hsel_i ----------+----------------+
 haddr_i -------->| address phase  |
 htrans_i ------->| range/alignment|
 hwrite_i ------->| region decode  |
 hsize_i -------->| capture regs   |
                 +--------+-------+
                          |
          +---------------+---------------+
          |                               |
          v                               v
 +----------------+              +----------------+
 | OTP data array |              | OTP registers  |
 | default all 1s |              | CTRL STATUS    |
 | 1 -> 0 only    |              | ADDR WDATA     |
 +-------+--------+              | RDATA KEY LOCK |
         |                       +--------+-------+
         |                                |
         +---------------+----------------+
                         |
                         v
                +----------------+
                | response mux   |
                | HRDATA/HRESP   |
                +--------+-------+
                         |
       +-----------------+----------------+
       |                                  |
       v                                  v
 hrdata_o registered read data       hresp_o OKAY/ERROR
 hready_o always 1
```

## 3. Address Layout

For the default SoC map:

| Region | Base | Size | Description |
| --- | --- | --- | --- |
| OTP data | `OTP_BASE` | `OTP_DATA_SIZE` | Executable read-only OTP contents |
| OTP registers | `OTP_REG_BASE` | `OTP_REG_WINDOW_SIZE` | Programming/status registers |

`OTP_REG_WINDOW_SIZE` is 256 bytes.

## 4. Registers

Offsets are relative to `OTP_REG_BASE`.

| Offset | Register | Access | Description |
| --- | --- | --- | --- |
| `0x00` | `OTP_CTRL` | W | bit0 program enable, bit1 start, bit2 clear status |
| `0x04` | `OTP_STATUS` | R | bit0 busy, bit1 done, bit2 error, bit3 locked |
| `0x08` | `OTP_ADDR` | R/W | OTP data word address |
| `0x0C` | `OTP_WDATA` | R/W | Program data |
| `0x10` | `OTP_RDATA` | R | Data readback from `OTP_ADDR` |
| `0x14` | `OTP_KEY` | R/W | Write `OTP_KEY_VALUE` to unlock programming |
| `0x18` | `OTP_LOCK` | R/W | Write bit0=1 to lock programming |

## 5. Programming Semantics

OTP data bits default to `1`.

Programming is only accepted when:

```text
KEY is unlocked
LOCK is not set
OTP_ADDR is inside the data window
CTRL.program_enable = 1
CTRL.start = 1
WDATA does not request any 0 -> 1 bit transition
```

On accepted programming:

```text
otp_word_next = otp_word_current & OTP_WDATA
STATUS.done = 1
STATUS.error = 0
```

On rejected programming:

```text
OTP data is unchanged
STATUS.done = 0
STATUS.error = 1
```

Writing `CTRL.clear` clears `done` and `error`.

## 6. AHB-Lite Behavior

`ahb_otp` implements a one-cycle response model:

```text
cycle N:
  capture selected NONSEQ/SEQ address/control

cycle N+1:
  return registered read data or write response
```

Supported data-window reads:

```text
byte
halfword
word
```

Register accesses must be aligned word accesses.

Error response:

```text
out-of-range selected transfer -> ERROR
misaligned selected transfer   -> ERROR
unsupported register size      -> ERROR
direct data-window write       -> ERROR
unknown register access        -> ERROR
```

`HREADY` is always high.

## 7. Implementation Targets

| Target macro | Implementation intent |
| --- | --- |
| `WASP1_TARGET_IC` | IC implementation path. The open RTL model keeps the boundary ready for OTP macro replacement. |
| `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | Adds Xilinx-friendly RAM style attributes so the data array can infer Virtex-7 block RAM. |
| `WASP1_TARGET_SIM_GENERIC` | Default generic simulation model when no explicit target macro is defined. |

## 8. Verification Summary

Verified by `tb_ahb_otp`.

Coverage includes:

```text
reset output state
default erased data reads
direct data write rejection
unlock key behavior
successful 1 -> 0 programming
legal repeated programming
illegal 0 -> 1 programming rejection
programming without key rejection
out-of-range programming rejection
misaligned and unknown-register AHB errors
deterministic random programming/readback
lock behavior
generic, IC, and Virtex-7 target lint
```
