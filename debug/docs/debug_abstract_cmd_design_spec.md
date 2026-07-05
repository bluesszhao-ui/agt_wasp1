# debug_abstract_cmd Design Spec

## 1. Scope

The block decodes and executes the RV32 GPR subset of Access Register commands,
local CSR reads for `misa`, `dcsr`, and core-captured `dpc`, and the minimal
`dcsr.step` write used for single-step. Other CSR writes, all other CSR
addresses, FPR access, postincrement, program-buffer execution, memory access,
and other command types remain explicitly unsupported.

## 2. Editable FSM/Block Diagram

editable source: `debug/docs/diagrams/debug_abstract_cmd_fsm.graffle`
preview export: none
detail level: L3
clock domains: `clk_i/rst_ni` for every `SEQ` block

The editable OmniGraffle diagram separates the command/data interface, decode
policy, FSM state, request registers, completion registers, register-access
interface, and DMI-register completion pulses into explicit `IF`, `COMB`, and
`SEQ` timing-class blocks. The historical PNG
`debug/docs/images/debug_abstract_cmd_fsm.png` remains as a reference export.

## 3. FSM

| State | Function |
| --- | --- |
| `IDLE` | Decode a one-cycle command pulse |
| `ISSUE` | Hold decoded GPR request until accepted |
| `WAIT` | Wait for `debug_reg_access` response |
| `COMPLETE` | Pulse cmderr or successful read data0 update |

```text
IDLE -> ISSUE:
  command_valid && dmactive && encoding_supported && hart_halted &&
  transfer && GPR_transfer

IDLE -> COMPLETE:
  command_valid && dmactive &&
  (unsupported || !hart_halted || !transfer || supported_local_CSR_access)

ISSUE -> WAIT:
  reg_cmd_valid && reg_cmd_ready

WAIT -> COMPLETE:
  reg_rsp_valid && reg_rsp_ready

ISSUE/WAIT -> COMPLETE:
  !hart_halted, with CMDERR_HALT_RESUME and reg_flush

ISSUE/WAIT -> IDLE:
  !dmactive, with silent abort and reg_flush

COMPLETE -> IDLE:
  unconditional after one reporting cycle
```

## 4. Decoder

The raw `command_i` field extraction and support predicate are combinational.
Only a transfer command requires `aarsize=2` and either a GPR register range,
one of the supported local CSR reads, or the supported `dcsr.step` write. This
keeps the architecturally valid transfer-disabled no-op independent of unused
fields. Hart halted policy is checked separately and therefore still applies to
no-op Access Register commands.

## 5. Request Registers

On a command pulse, the block captures:

```text
reg_write_q = command.write
reg_addr_q  = command.regno[4:0]
reg_wdata_q = data0_i
```

These registers drive the entire downstream request and therefore hold stable
under request backpressure.

## 6. Completion Registers

`completion_error_q` stores the mapped `cmderr`. A successful GPR read captures
`read_result_q` from `debug_reg_access` and sets `read_result_valid_q`. A
successful supported CSR read sets the same completion registers locally during
command capture. The `COMPLETE` state converts these registers into one-cycle
pulses for `debug_dmi_regs`.

Successful GPR writes, supported `dcsr.step` writes, transfer-disabled
commands, and unsupported CSR writes report no data0 pulse because no read
value is produced. For the supported CSR probe set, `misa` is fixed, `dcsr`
combines the fixed discovery/cause value with the latched step bit, and `dpc`
is forwarded from `hart_dpc_i`, which is driven by the core-side Debug PC
capture logic.

`dcsr_step_q` is local sequential state. It resets to zero and clears when
`dmactive_i` is deasserted. A supported Access Register write to `dcsr` updates
only this bit from `data0_i[2]`; other DCSR fields remain fixed readback
metadata in this stage.

## 7. Target Behavior

The block is target-neutral synthesizable logic and includes
`wasp1_target_defs.svh`. Target macros do not change command semantics.
