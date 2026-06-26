# ahb_i2c Design Spec

## 1. Scope

`ahb_i2c` is a single-clock AHB-Lite I2C master peripheral. It contains no clock
domain crossings and is target-neutral synthesizable logic for IC,
Virtex-7 FPGA, and generic simulation builds.

## 2. Editable Diagram

```text
editable source: i2c/docs/diagrams/ahb_i2c_block.graffle
preview export:  none
detail level:    L3
clock domain:    SEQ clk=hclk_i rst=hresetn_i
```

The diagram explicitly separates `COMB` and `SEQ` blocks. `SEQ` blocks use the
common `hclk_i/hresetn_i` clock/reset domain.

## 3. Implementation Blocks

| Block | Timing class | Function |
| --- | --- | --- |
| AHB address decode | `COMB` | Checks select, address range, alignment, word size, and known register offsets. |
| Request phase registers | `SEQ hclk_i/hresetn_i` | Capture AHB address-phase metadata for the following response/data phase. |
| Software registers | `SEQ hclk_i/hresetn_i` | Hold enable, IRQ enable, prescale, TX byte, RX byte, done, ACK error, RX valid, and command fields. |
| Prescale tick decode | `COMB` | Generates the byte-engine phase tick from `div_q == 0`. |
| I2C byte FSM | `SEQ hclk_i/hresetn_i` | Sequences START, data bits, ACK, optional STOP, and DONE. |
| Open-drain line decode | `COMB` | Drives SCL/SDA output enables from FSM state, command direction, TX bit, and read ACK policy. |
| Read/status/output decode | `COMB` | Packs `DATA`, `STATUS`, `CTRL`, `PRESCALE`, `hrdata_o`, `hresp_o`, and `i2c_irq_o`. |

## 4. FSM States

| State | Meaning | Key output behavior |
| --- | --- | --- |
| `I2C_IDLE` | No active byte transaction | SCL/SDA released. |
| `I2C_START_A` | Pre-start high phase | SCL/SDA released. |
| `I2C_START_B` | START condition | SDA driven low while SCL is released. |
| `I2C_BIT_LOW` | Data low phase | SCL driven low; SDA driven according to TX bit or released for RX. |
| `I2C_BIT_HIGH` | Data sample/high phase | SCL released; RX samples SDA; TX keeps bit drive policy. |
| `I2C_ACK_LOW` | ACK low phase | SCL driven low; RX optionally drives ACK low. |
| `I2C_ACK_HIGH` | ACK sample/high phase | TX samples slave ACK; RX commits received byte. |
| `I2C_STOP_LOW` | STOP setup | SCL/SDA driven low. |
| `I2C_STOP_HIGH` | STOP condition | SCL released while SDA remains low for one phase. |
| `I2C_DONE` | Completion pulse state | Returns to idle and latches `done_q`. |

## 5. Register Update Priority

Each cycle uses this effective priority:

```text
reset
  -> initialize all state
active FSM tick
  -> advance byte engine and capture SDA when required
AHB data phase write
  -> update registers, clear status, or start/reject command
AHB address phase
  -> capture next request metadata
```

Software writes are placed after the default FSM assignments in the
`always_ff`, so accepted `CMD` and `CTRL.clear` writes override idle defaults in
the same cycle. A `CMD` write is accepted only when `CTRL.enable=1` and the FSM
is idle.

## 6. Divider Behavior

`PRESCALE` is a 16-bit reload value. When the FSM is active, `div_q` counts down
to zero. `tick` is asserted when `div_q == 0`, then `div_q` reloads from
`prescale_q`. `PRESCALE=0` is legal and advances one FSM phase per `hclk_i`
cycle, which is useful for fast simulation and simple low-speed integrations.

## 7. Open-Drain Policy

The module never drives logic high on SCL or SDA:

```text
i2c_scl_o = 0
i2c_sda_o = 0
*_oe_o = 1 -> drive low
*_oe_o = 0 -> release line to pull-up
```

For TX data bits, SDA is driven only when the transmitted bit is zero. For RX
data bits, SDA is released so the external slave can drive the sampled value.
For RX ACK, `ACK_VALUE=0` drives SDA low and `ACK_VALUE=1` releases SDA.

## 8. Error Handling

Address phase errors are captured in `req_err_q`. Unknown register offsets and
illegal `CMD` writes are detected in the data phase and return AHB ERROR. The
slave is always ready, so `hready_o=1`.

## 9. Target Support

The RTL does not instantiate target-specific cells. The same source is linted
for:

```text
WASP1_TARGET_SIM_GENERIC
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```
