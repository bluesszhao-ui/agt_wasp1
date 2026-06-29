# ahb_decoder Design Spec

## 1. Scope

`ahb_decoder` converts a selected AHB address into a one-hot slave select vector.

It is a pure combinational block. It does not use a clock or reset.

## 2. Editable Block Diagram

```text
editable source: bus/docs/diagrams/ahb_decoder_block.graffle
preview export:  none
detail level:    L1
clock domains:   none; pure combinational logic
```

The diagram separates address/active inputs, region comparison, one-hot select
generation, and decoder outputs.

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
