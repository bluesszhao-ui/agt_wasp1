# debug_abstract_cmd Design Spec

## 1. Scope

The block decodes and executes the RV32 GPR subset of Access Register commands,
physical Access Memory commands, local CSR reads for debugger discovery, the
minimal `dcsr.step` write used for single-step, and two RV32 `mcontrol`
execute-address trigger slots used by OpenOCD/GDB hardware breakpoints. FPR
access, program-buffer execution, virtual memory access, data/load/store
triggers, and System Bus Access remain explicitly unsupported.

## 2. Editable FSM/Block Diagram

editable source: `debug/docs/diagrams/debug_abstract_cmd_fsm.graffle`
preview export: none
detail level: L3
clock domains: `clk_i/rst_ni` for every `SEQ` block

The editable OmniGraffle diagram separates the command/data interface, decode
policy, FSM state, request registers, completion registers, Access Memory
request registers, trigger CSR registers, register/memory interfaces, and
DMI-register completion pulses into explicit `IF`, `COMB`, and `SEQ`
timing-class blocks. The historical PNG
`debug/docs/images/debug_abstract_cmd_fsm.png` remains as a reference export.

## 3. FSM

| State | Function |
| --- | --- |
| `IDLE` | Decode a one-cycle command pulse |
| `ISSUE` | Hold decoded GPR or memory request until accepted |
| `WAIT` | Wait for `debug_reg_access` or halted-memory response |
| `COMPLETE` | Pulse cmderr, successful read data0 update, or postincrement data1 update |

```text
IDLE -> ISSUE:
  command_valid && dmactive && encoding_supported && hart_halted &&
  transfer && downstream_GPR_or_memory_transfer

IDLE -> COMPLETE:
  command_valid && dmactive &&
  (unsupported || !hart_halted || !transfer || supported_local_CSR_access)

ISSUE -> WAIT:
  (reg_cmd_valid && reg_cmd_ready) || (mem_cmd_valid && mem_cmd_ready)

WAIT -> COMPLETE:
  (reg_rsp_valid && reg_rsp_ready) || (mem_rsp_valid && mem_rsp_ready)

ISSUE/WAIT -> COMPLETE:
  !hart_halted, with CMDERR_HALT_RESUME and reg_flush/mem_flush

ISSUE/WAIT -> IDLE:
  !dmactive, with silent abort and reg_flush

COMPLETE -> IDLE:
  unconditional after one reporting cycle
```

## 4. Decoder

The raw `command_i` field extraction and support predicate are combinational.
Only an Access Register transfer command requires `aarsize=2` and either a GPR
register range, one of the supported local CSR reads, the supported `dcsr.step`
write, or a supported trigger CSR access. Access Memory commands use the
Debug Spec `cmdtype=2` encoding, physical addressing, byte/half/word sizes, and
optional postincrement. Hart halted policy is checked separately and therefore
still applies to transfer-disabled no-op commands.

## 5. Request Registers

On a command pulse, the block captures:

```text
reg_write_q = command.write
reg_addr_q  = command.regno[4:0]
reg_wdata_q = data0_i
mem_write_q = command.write
mem_addr_q  = data1_i
mem_size_q  = decoded byte/half/word size
mem_wdata_q/mem_wstrb_q = lane-aligned data0_i
```

These registers drive the entire downstream request and therefore hold stable
under request backpressure. Access Memory postincrement state is captured in
the same command-accept cycle and reported through `data1_we_o` only on a
successful completion.

## 6. Completion Registers

`completion_error_q` stores the mapped `cmderr`. A successful GPR read captures
`read_result_q` from `debug_reg_access` and sets `read_result_valid_q`. A
successful supported CSR read sets the same completion registers locally during
command capture. The `COMPLETE` state converts these registers into one-cycle
pulses for `debug_dmi_regs`.

Successful GPR writes, supported `dcsr.step` writes, trigger CSR writes,
transfer-disabled commands, and unsupported CSR writes report no data0 pulse
because no read value is produced. For the supported CSR probe set, `misa` is
fixed, `dcsr` combines the fixed RV32/M-mode discovery value with
`hart_dcsr_cause_i` and the latched step bit, and `dpc` is forwarded from
`hart_dpc_i`, which is driven by the core-side Debug PC capture logic.

`dcsr_step_q` is local sequential state. It resets to zero and clears when
`dmactive_i` is deasserted. A supported Access Register write to `dcsr` updates
only this bit from `data0_i[2]`; other DCSR fields remain fixed readback
metadata in this stage.

`trigger_select_q`, `trigger_tdata1_q[2]`, and `trigger_tdata2_q[2]` are local
sequential state. Reset and DM deactivation select trigger 0, return every
`tdata1` slot to a disabled RV32 `mcontrol` image, and clear every `tdata2`
slot. `tselect` writes select slot 0 or 1, while out-of-range writes clamp to
the last legal slot. The combinational WARL filter accepts only `type=2`,
equality match, M-mode execute, and `action=debug mode`. Each trigger output
toward the core is asserted only when that slot's filtered `tdata1` image is
fully enabled; the compare address is that slot's registered `tdata2` value.

## 7. Target Behavior

The block is target-neutral synthesizable logic and includes
`wasp1_target_defs.svh`. Target macros do not change command semantics.
