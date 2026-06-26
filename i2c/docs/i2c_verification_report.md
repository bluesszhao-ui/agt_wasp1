# i2c Verification Report

## 1. Commands

```text
make -C i2c lint
make -C i2c lint-ic
make -C i2c lint-fpga-v7
make -C i2c sim
make -C common lint
```

## 2. Results

| Check | Result |
| --- | --- |
| Generic lint | PASS |
| IC-target lint | PASS |
| Virtex-7-target lint | PASS |
| `tb_ahb_i2c` simulation | PASS |
| Common package lint | PASS |

Simulation coverage counters:

```text
pass_count=110
reg_count=36
write_tx_count=6
read_rx_count=2
error_count=5
random_count=4
line_check_count=50
```

## 3. Time-Sequenced Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-35ns | Reset asserted for three 10ns clock cycles, then released | HREADY high, HRESP OKAY, HRDATA zero, IRQ low, SCL/SDA released | PASS |
| 35ns-135ns | Read DATA, STATUS, CTRL, PRESCALE, CMD reset values | Reset register values match spec | PASS |
| 135ns-215ns | Perform out-of-range, misaligned, byte-size, and unknown register accesses | All return AHB ERROR | PASS |
| 215ns-295ns | Program `PRESCALE=0`, enable controller and IRQ, read back visible registers | Divider and CTRL readbacks match programmed values | PASS |
| 295ns-575ns | Write `0xA5`, start TX with START/STOP, slave ACKs low | DONE and IRQ set, ACKERR clear, each bit-high SDA OE matches TX bit | PASS |
| 575ns-865ns | Clear status, write `0x3C`, start TX with START/STOP, slave NACKs high | DONE, IRQ, and ACKERR set | PASS |
| 865ns-1135ns | Clear status, start RX of `0x5A` with master ACK | DATA reads `0x5A`, RX_VALID/DONE/IRQ set, ACK drives SDA low | PASS |
| 1135ns-1405ns | Clear status, start RX of `0xC3` with master NACK | DATA reads `0xC3`, RX_VALID/DONE/IRQ set, ACK phase releases SDA | PASS |
| 1405ns-1665ns | Start TX and issue a second `CMD` while FSM is busy | Second command returns AHB ERROR, first transaction completes | PASS |
| 1665ns-3000ns | Four deterministic random TX bytes with slave ACK | All complete with DONE/IRQ and line-level bit checks | PASS |

## 4. Residual Risk

The module does not implement multi-master arbitration or clock stretching.
Those capabilities are intentionally outside the current minimal wasp1 I2C
contract. Board-level pull-up strength, pad open-drain implementation, and any
external I2C timing margin checks remain integration and FPGA/IC signoff items.
