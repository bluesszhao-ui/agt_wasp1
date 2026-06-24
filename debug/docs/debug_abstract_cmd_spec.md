# debug_abstract_cmd Spec

## 1. Purpose

`debug_abstract_cmd` decodes RISC-V Debug Spec 0.13.x abstract commands and
controls the verified `debug_reg_access` transport. The first implementation
supports RV32 integer Access Register commands only.

## 2. Supported Command

| Field | Requirement |
| --- | --- |
| `cmdtype[31:24]` | `0`: Access Register |
| reserved bit 23 | zero |
| `aarsize[22:20]` | `2`: 32-bit, when transfer is set |
| `aarpostincrement[19]` | zero |
| `postexec[18]` | zero; no program buffer yet |
| `transfer[17]` | zero for no-op or one for GPR transfer |
| `write[16]` | zero reads GPR; one writes GPR |
| `regno[15:0]` | `0x1000..0x101F` for x0-x31 |

A command with `transfer=0`, supported command type, and no unsupported option
is a successful no-op; size, register number, and write direction are ignored.
The selected hart must still be halted for every accepted Access Register
command, including this transfer-disabled no-op.

## 3. Error Mapping

```text
unsupported command type/field/register/size -> CMDERR_NOTSUP
hart not halted before or during transfer    -> CMDERR_HALT_RESUME
downstream register-access error             -> CMDERR_EXCEPTION
```

DM deactivation aborts silently because `debug_dmi_regs` resets abstract state
when `dmactive` clears.

## 4. Data0 Behavior

For writes, `data0_i` is captured with the command and forwarded as GPR write
data. Successful writes do not change data0.

For reads, successful downstream data generates one `data0_we_o` pulse. Failed,
unsupported, aborted, write, and no-op commands must not update data0.

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
