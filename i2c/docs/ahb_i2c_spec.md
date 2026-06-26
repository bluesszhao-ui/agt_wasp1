# ahb_i2c Spec

## 1. Purpose

`ahb_i2c` provides the SoC I2C master peripheral. Software programs a prescale
divider, writes transmit data or requests receive data, and starts one 8-bit
I2C byte transaction per `CMD` write.

The block is intentionally minimal for wasp1: it is a single-master controller,
does not implement multi-master arbitration, and exposes open-drain SCL/SDA
drive enables for integration-level pull-up handling.

## 2. Register Requirements

The I2C controller must expose word registers at `I2C_BASE`:

| Offset | Name | Access | Requirement |
| --- | --- | --- | --- |
| `0x00` | `DATA` | RW/RO | Write TX byte; read last RX byte. |
| `0x04` | `STATUS` | RO | Busy, done, ACK error, RX valid, IRQ pending. |
| `0x08` | `CTRL` | RW | Enable, IRQ enable, write-one clear. |
| `0x0C` | `PRESCALE` | RW | 16-bit SCL phase divider reload value. |
| `0x10` | `CMD` | WO | Start one byte transaction. |

`CMD` bits are:

| Bit | Name | Requirement |
| --- | --- | --- |
| `0` | `START` | Generate START before the byte when set. |
| `1` | `READ` | Receive byte when set; transmit `DATA` when clear. |
| `2` | `STOP` | Generate STOP after ACK phase when set. |
| `3` | `ACK_VALUE` | During read, `0` drives ACK low and `1` releases SDA for NACK. |

## 3. Behavior Requirements

The controller must be an always-ready AHB-Lite slave with one-cycle delayed
read data/response relative to the address phase.

When enabled and idle, a valid `CMD` write starts one byte transaction. While
busy, a `CMD` write must return AHB ERROR and must not restart or corrupt the
current transaction.

For transmit bytes, the controller drives SDA low for zero bits and releases
SDA for one bits. It samples SDA during the ACK high phase; sampled high sets
`STATUS.ackerr`.

For receive bytes, the controller releases SDA during data bits, samples one
bit per SCL high phase, writes the assembled byte to `DATA`, and sets
`STATUS.rx_valid`. During the ACK phase it drives SDA low when `ACK_VALUE=0`
and releases SDA when `ACK_VALUE=1`.

`STATUS.done` is set when the byte transaction returns to idle. `i2c_irq_o`
must assert when `STATUS.done && CTRL.irq_en`.

## 4. Open-Drain Requirements

`i2c_scl_o` and `i2c_sda_o` are constant zero drive values. The corresponding
`*_oe_o` output selects whether the pad is driven low or released. Pull-ups are
provided outside this module.

## 5. Error Requirements

Only aligned word register accesses are supported. Misaligned, non-word,
out-of-range, and unknown register accesses must return AHB ERROR. Writes to
`CMD` while disabled must return AHB ERROR.

## 6. Verification Requirements

Verification must cover reset values, register paths, transmit ACK and NACK,
receive data sampling, read ACK/NACK drive policy, busy command rejection,
illegal AHB access responses, deterministic random TX bytes, open-drain line
behavior, and target macro lint.
