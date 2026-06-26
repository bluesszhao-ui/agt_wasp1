# ahb_wdg Design Spec

## 1. Scope

`ahb_wdg` is a single-clock AHB-Lite watchdog peripheral. It contains no clock
domain crossings and is target-neutral synthesizable logic for IC,
Virtex-7 FPGA, and generic simulation builds.

## 2. Editable Diagram

```text
editable source: wdg/docs/diagrams/ahb_wdg_block.graffle
preview export:  none
detail level:    L2
clock domain:    SEQ clk=hclk_i rst=hresetn_i
```

## 3. Implementation Blocks

The design separates interface decode, sequential register/state storage, and
combinational output/status decode:

| Block | Timing class | Function |
| --- | --- | --- |
| AHB address decode | `COMB` | Checks select, address range, alignment, and word size. |
| Request phase registers | `SEQ hclk_i/hresetn_i` | Capture address-phase metadata for the response/data phase. |
| Control/status registers | `SEQ hclk_i/hresetn_i` | Hold enable, IRQ enable, reset enable, timeout, count, expired, reset request, and key error. |
| Watchdog tick/compare | `COMB` plus `SEQ` update | Computes `count + 1 >= timeout` and updates expiry state. |
| Read/status/output decode | `COMB` | Packs `CTRL`, `STATUS`, `TIMEOUT`, `COUNT`, `wdg_irq_o`, and `wdg_reset_req_o`. |

## 4. Register Update Priority

Each cycle uses this effective priority:

```text
reset
  -> initialize all state
software CTRL.clear or valid KICK in the data phase
  -> clear count/expired/reset_req
watchdog enabled and not expired
  -> increment count or latch expiry
bad KICK
  -> latch keyerr without feeding watchdog
```

In RTL, software writes are placed after the default watchdog tick assignments
inside the same `always_ff`, so clear/kick assignments override a same-cycle
tick or expiry.

## 5. Expiry and Kick Behavior

`count_plus_one` is compared with `timeout_q`. This makes `TIMEOUT=N` expire
after N enabled watchdog ticks from a cleared count. `TIMEOUT=0` is treated as
immediate expiry to avoid an unreachable zero timeout state.

The `KICK` register has no readable state. A correct key write resets the count
and clears expired/reset request. An incorrect key write is accepted at the AHB
protocol level but sets `STATUS.keyerr`, allowing software to diagnose a bad
feed attempt without turning data value mistakes into bus protocol errors.

## 6. Error Handling

The AHB response path is one cycle after the address phase. Address phase errors
are captured in `req_err_q`. Unknown register offsets are detected in the data
phase and also return ERROR. The slave is always ready, so `hready_o=1`.

## 7. Target Support

The RTL does not instantiate target-specific cells. The same source is linted
for:

```text
WASP1_TARGET_SIM_GENERIC
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```
