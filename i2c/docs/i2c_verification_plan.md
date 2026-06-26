# i2c Verification Plan

## 1. Scope

The module-level verification target is `ahb_i2c`. The testbench drives the AHB
slave interface and models a simple external I2C slave through sampled SDA.

## 2. Test Items

| Item | Goal | Method |
| --- | --- | --- |
| Reset | Check reset values and released lines | Assert reset for three 10ns cycles and inspect outputs/registers. |
| Register access | Check legal reads/writes | Program `CTRL`, `PRESCALE`, and `DATA`; read visible registers. |
| AHB errors | Check bus contract | Exercise misaligned, byte-size, unknown, and out-of-range accesses. |
| TX ACK | Check transmit bit drive and done IRQ | Send `0xA5`, drive ACK low, verify SDA OE per bit and status. |
| TX NACK | Check ACK error latch | Send `0x3C`, drive ACK high, verify `STATUS.ackerr`. |
| RX data | Check sampled byte and RX valid | Feed `0x5A` and `0xC3` during bit-high states. |
| RX ACK policy | Check master ACK/NACK drive | Verify ACK low drive for `ACK_VALUE=0` and release for `ACK_VALUE=1`. |
| Busy reject | Check command protection | Start a transaction and issue a second `CMD` while busy. |
| Random TX | Broaden bit-pattern coverage | Run four deterministic TX bytes with ACK. |
| Target lint | Check IC/FPGA macro compatibility | Run generic, IC, and Virtex-7 lint targets. |

## 3. Coverage Intent

The self-checking testbench maintains counters for total checks, register
accesses, write transactions, read transactions, AHB error responses,
deterministic random cases, and line-level behavior checks.

Open-drain line behavior is checked during each transmitted bit-high phase so
that TX data-path mistakes are caught even if final status bits look correct.

## 4. Pass Criteria

All lint targets and `tb_ahb_i2c` simulation must pass without `$error` or
`$fatal`. The verification report must include the observed coverage counters
and a time-sequenced action table.
