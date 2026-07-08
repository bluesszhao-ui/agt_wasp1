# debug_abstract_cmd Spec

## 1. Purpose

`debug_abstract_cmd` decodes RISC-V Debug Spec 0.13.x abstract commands,
controls the verified `debug_reg_access` transport, drives halted-core memory
accesses, and provides the CSR probes needed by OpenOCD/GDB. The implementation
supports RV32 integer GPR Access Register commands, physical Access Memory
byte/half/word transfers through the halted core, local reads of `misa`,
`mstatus`, `dcsr`, and the core-captured `dpc`, plus writes to the `dcsr.step`
bit used for single-step.

## 2. Supported Access Register Command

| Field | Requirement |
| --- | --- |
| `cmdtype[31:24]` | `0`: Access Register |
| reserved bit 23 | zero |
| `aarsize[22:20]` | `2`: 32-bit, when transfer is set |
| `aarpostincrement[19]` | zero |
| `postexec[18]` | zero; no program buffer yet |
| `transfer[17]` | zero for no-op or one for GPR/CSR transfer |
| `write[16]` | zero reads; one writes GPR or the supported `dcsr.step` bit |
| `regno[15:0]` | `0x1000..0x101F` for x0-x31, read-only `0x0301` `misa`, read-only `0x0300` `mstatus`, read/write-step `0x07B0` `dcsr`, read-only `0x07B1` `dpc`, or OpenOCD probe CSRs |

A command with `transfer=0`, supported command type, and no unsupported option
is a successful no-op; size, register number, and write direction are ignored.
The selected hart must still be halted for every accepted Access Register
command, including this transfer-disabled no-op.

CSR reads complete locally for the supported probe set. Unimplemented CSR
probes complete as zero so OpenOCD does not disable abstract CSR access after
probing optional trigger or status CSRs. CSR writes complete as no-ops except
for `dcsr.step`.

```text
misa      -> 0x40000100, RV32 + I extension
mstatus   -> 0x00000000, machine mode baseline with no writable status bits yet
dcsr read -> 0x400000C3 with bit 2 reflecting the latched step bit
dcsr write-> updates only bit 2, DCSR.step; other written bits are ignored
dpc       -> hart_dpc_i, the core-captured Debug PC/resume PC
```

## 3. Supported Access Memory Command

| Field | Requirement |
| --- | --- |
| `cmdtype[31:24]` | `2`: Access Memory |
| `aamvirtual[23]` | zero; physical memory only |
| `aamsize[22:20]` | `0`, `1`, or `2`: byte, halfword, or word |
| `aampostincrement[19]` | optional address increment after success |
| `write[16]` | zero reads into data0; one writes data0 to memory |
| `target-specific[15:14]` | ignored by this stage and expected zero from OpenOCD |

`data1` supplies the byte address. Byte and halfword writes lane-align `data0`
and generate byte strobes. Byte and halfword reads extract the selected lane
from the 32-bit halted-core response and zero-extend into `data0`.

## 4. Error Mapping

```text
unsupported command type/field/register/size -> CMDERR_NOTSUP
hart not halted before or during transfer    -> CMDERR_HALT_RESUME
downstream register-access error             -> CMDERR_EXCEPTION
downstream memory-access error               -> CMDERR_BUS
```

DM deactivation aborts silently because `debug_dmi_regs` resets abstract state
when `dmactive` clears.

## 5. Data Register Behavior

For writes, `data0_i` is captured with the command and forwarded as GPR write
data. Successful writes do not change data0.

For GPR reads, successful downstream data generates one `data0_we_o` pulse.
For local CSR reads, the controller generates the same data0 write pulse
without issuing a downstream register command. A supported `dcsr.step` write
updates the local step bit and does not update data0. Failed, unsupported,
aborted, GPR write, and no-op commands must not update data0.

For Access Memory reads, successful memory data generates one `data0_we_o`
pulse with lane-extracted data. For Access Memory writes, `data0_i` is captured
with the command and forwarded to memory. When postincrement is set, a
successful memory command generates one `data1_we_o` pulse with the address
advanced by the access size.

## 6. Busy and Handshake Requirements

`busy_o` asserts from command capture through a one-cycle completion state.
Decoded register and memory commands use ready/valid request and response
channels. Request fields and completion data must remain registered and stable.

`command_valid_i` is accepted only in IDLE. A defensive pulse while busy is
ignored; normal integration prevents it because `debug_dmi_regs` rejects a
command write while `abstractcs.busy` is set.

`reg_flush_o` and `mem_flush_o` assert on DM deactivation or loss of halted
state while a downstream transaction is active.

## 7. Reset and Targets

All state uses `clk_i` with asynchronous active-low `rst_ni`. Behavior must be
identical for generic simulation, IC, and Xilinx Virtex-7 FPGA targets.
