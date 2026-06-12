# ahb_sram Design Spec

## 1. Scope

`ahb_sram` is a reusable AHB-Lite SRAM slave for wasp1.

It is intended to be used for I-SRAM and D-SRAM wrappers. The module supports
IC and FPGA implementation targets through `common/rtl/wasp1_target_defs.svh`.
The current open-source RTL uses a synthesizable word-array model behind a
stable AHB-facing behavior.

## 2. Block Diagram

```text
              hclk_i / hresetn_i
                      |
                      v
 hsel_i ----------+----------------+
 haddr_i -------->| address phase  |
 htrans_i ------->| valid/range/   |
 hwrite_i ------->| alignment check|
 hsize_i -------->| capture regs   |
                 +--------+-------+
                          |
                          | one-cycle AHB response/data phase
                          v
                 +----------------+
 hwdata_i ------>| byte lane      |
                 | write merge    |
                 +--------+-------+
                          |
                          v
                 +----------------+
                 | SRAM word array|
                 | 32-bit words   |
                 +--------+-------+
                          |
       +------------------+-------------------+
       |                                      |
       v                                      v
 hrdata_o read data                    hresp_o OKAY/ERROR
 hready_o always 1
```

## 3. Ports

| Port | Direction | Description |
| --- | --- | --- |
| `hclk_i` | input | AHB clock |
| `hresetn_i` | input | Active-low reset |
| `hsel_i` | input | Slave select |
| `haddr_i` | input | Full AHB address |
| `htrans_i` | input | AHB transfer type |
| `hwrite_i` | input | Write indicator |
| `hsize_i` | input | Transfer size |
| `hwdata_i` | input | Write data, used in data phase |
| `hrdata_o` | output | Registered read data |
| `hready_o` | output | Always high in current implementation |
| `hresp_o` | output | Registered OKAY/ERROR response |

## 4. Parameters

| Parameter | Description |
| --- | --- |
| `ADDR_WIDTH` | Address width, default 32 |
| `DATA_WIDTH` | Data width, default 32 |
| `BASE_ADDR` | Full address base for range checking |
| `MEM_BYTES` | SRAM capacity in bytes |

## 5. Implementation Targets

| Target macro | Implementation intent |
| --- | --- |
| `WASP1_TARGET_IC` | IC implementation path. The current model remains synthesizable and keeps the wrapper boundary ready for later SRAM macro replacement. |
| `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | Adds Xilinx-friendly RAM style attributes so the array can infer Virtex-7 block RAM. |
| `WASP1_TARGET_SIM_GENERIC` | Default generic simulation model when no explicit target macro is defined. |

## 6. Behavior

`ahb_sram` implements a one-cycle response model:

```text
cycle N:
  capture selected NONSEQ/SEQ address/control

cycle N+1:
  return read data or write response
  write data phase updates memory for valid writes
```

Supported sizes:

```text
byte
halfword
word
```

Alignment rules:

```text
byte: any address
halfword: address[0] must be 0
word: address[1:0] must be 0
```

Error response:

```text
out-of-range selected transfer -> ERROR
misaligned selected transfer   -> ERROR
unsupported HSIZE              -> ERROR
```

`HREADY` is always high. Stalling SRAM behavior can be added later if needed.

## 7. Sequential State Diagram

```text
Reset:
  captured transfer valid = 0
  hrdata_o = 0
  hresp_o = OKAY

Cycle N address phase:
  if selected transfer:
    capture address, write/read, size, and validity/error classification
  else:
    capture idle/no-transfer state

Cycle N+1 data/response phase:
  if captured transfer has error:
    hresp_o <- ERROR
    hrdata_o <- 0
    memory holds

  else if captured write:
    merge hwdata_i into selected byte lanes
    memory[word] <- merged data
    hresp_o <- OKAY

  else if captured read:
    hrdata_o <- selected word/byte/halfword read data
    hresp_o <- OKAY
```

There is no explicit FSM enum. The AHB address-phase capture registers and the
SRAM word array are the sequential state.

## 8. Verification Summary

Verified by `tb_ahb_sram`.

Coverage includes:

```text
reset output state
word write/read
halfword write/read merge
all four byte lane writes
unselected transfer does not write
misaligned halfword/word error
out-of-range high address error
below-base address error
16 deterministic random word write/read pairs
```

Target-sensitive compile checks:

```text
make -C sram lint
make -C sram lint-ic
make -C sram lint-fpga-v7
```
