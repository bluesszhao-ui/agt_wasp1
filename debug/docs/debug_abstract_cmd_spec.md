# debug_abstract_cmd Spec

## 1. Purpose

`debug_abstract_cmd` decodes RISC-V Debug Spec 0.13.x abstract commands,
controls the verified `debug_reg_access` transport, and provides the minimal
read-only CSR probes needed by OpenOCD/GDB. The first implementation supports
RV32 integer GPR Access Register commands plus local reads of `misa`, `dcsr`,
and the core-captured `dpc`.

## 2. Supported Command

| Field | Requirement |
| --- | --- |
| `cmdtype[31:24]` | `0`: Access Register |
| reserved bit 23 | zero |
| `aarsize[22:20]` | `2`: 32-bit, when transfer is set |
| `aarpostincrement[19]` | zero |
| `postexec[18]` | zero; no program buffer yet |
| `transfer[17]` | zero for no-op or one for GPR/CSR transfer |
| `write[16]` | zero reads; one writes GPR |
| `regno[15:0]` | `0x1000..0x101F` for x0-x31, or read-only `0x0301` `misa`, `0x07B0` `dcsr`, `0x07B1` `dpc` |

A command with `transfer=0`, supported command type, and no unsupported option
is a successful no-op; size, register number, and write direction are ignored.
The selected hart must still be halted for every accepted Access Register
command, including this transfer-disabled no-op.

CSR reads complete locally for the supported probe set:

```text
misa -> 0x40000100, RV32 + I extension
dcsr -> 0x400000C3, Debug Spec 0.13-style Debug Mode, haltreq cause, M-mode
dpc  -> hart_dpc_i, the core-captured Debug PC/resume PC
```

CSR writes and all other CSR addresses remain unsupported.

## 3. Error Mapping

```text
unsupported command type/field/register/size/CSR write -> CMDERR_NOTSUP
hart not halted before or during transfer    -> CMDERR_HALT_RESUME
downstream register-access error             -> CMDERR_EXCEPTION
```

DM deactivation aborts silently because `debug_dmi_regs` resets abstract state
when `dmactive` clears.

## 4. Data0 Behavior

For writes, `data0_i` is captured with the command and forwarded as GPR write
data. Successful writes do not change data0.

For GPR reads, successful downstream data generates one `data0_we_o` pulse.
For local CSR reads, the controller generates the same data0 write pulse
without issuing a downstream register command. Failed, unsupported, aborted,
write, and no-op commands must not update data0.

## 5. Busy and Handshake Requirements

`busy_o` asserts from command capture through a one-cycle completion state.
Decoded register commands use ready/valid request and response channels. Request
fields and completion data must remain registered and stable.

`command_valid_i` is accepted only in IDLE. A defensive pulse while busy is
ignored; normal integration prevents it because `debug_dmi_regs` rejects a
command write while `abstractcs.busy` is set.

`reg_flush_o` asserts on DM deactivation or loss of halted state while a
downstream transaction is active.

## 6. Reset and Targets

All state uses `clk_i` with asynchronous active-low `rst_ni`. Behavior must be
identical for generic simulation, IC, and Xilinx Virtex-7 FPGA targets.
