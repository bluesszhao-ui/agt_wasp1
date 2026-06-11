# ahb_decoder Design Spec

## 1. Scope

`ahb_decoder` converts a selected AHB address into a one-hot slave select vector.

It is a pure combinational block. It does not use a clock or reset.

## 2. Block Diagram

```text
              haddr_i[31:0]
                   |
                   v
        +----------------------+
        |   address compare    |
        |                      |
        | OTP_BASE/OTP_SIZE    |
        | ISRAM_BASE/SIZE      |
        | DSRAM_BASE/SIZE      |
        | DMA_BASE/PERIPH_SIZE |
        | WDG_BASE/PERIPH_SIZE |
        | TIMER_BASE/...       |
        | INTC_BASE/...        |
        | UART_BASE/...        |
        | I2C_BASE/...         |
        | GPIO_BASE/...        |
        +----------+-----------+
                   |
 active_i -------->| enable decode
                   |
                   v
        +----------------------+
        | one-hot select       |
        |                      |
        | hsel_o[0]  OTP       |
        | hsel_o[1]  I-SRAM    |
        | hsel_o[2]  D-SRAM    |
        | hsel_o[3]  DMA       |
        | hsel_o[4]  WDG       |
        | hsel_o[5]  timer     |
        | hsel_o[6]  intc      |
        | hsel_o[7]  UART      |
        | hsel_o[8]  I2C       |
        | hsel_o[9]  GPIO      |
        | hsel_o[10] default   |
        +----------+-----------+
                   |
                   +---- default_sel_o
```

## 3. Ports

| Port | Direction | Description |
| --- | --- | --- |
| `haddr_i` | input | AHB address to decode |
| `active_i` | input | Decode enable for active transfers |
| `hsel_o` | output | One-hot slave select vector |
| `default_sel_o` | output | Alias of `hsel_o[AHB_SLAVE_DEFAULT]` |

## 4. Behavior

When `active_i` is low, no slave is selected.

When `active_i` is high:

```text
matched address   -> matching slave bit is set
unmatched address -> default slave bit is set
```

The decoder is expected to produce either all zeros or exactly one selected bit.

## 5. Verification Summary

Verified by `tb_ahb_decoder`.

Coverage includes:

```text
inactive decode
base/mid/end points for every region
before/after boundary checks
unmapped low/middle/high/top addresses
one-hot checks for every active decode
128 deterministic random addresses
```
