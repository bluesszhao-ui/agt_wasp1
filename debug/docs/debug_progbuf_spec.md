# debug_progbuf Spec

## 1. Purpose

`debug_progbuf` stores four RV32 instruction words for the future RISC-V Debug
Module Program Buffer execution path. This milestone verifies storage only. It
does not itself decode DMI addresses, advertise Program Buffer capability
through `abstractcs`, or execute debugger-supplied instructions. The later
`debug_dmi_regs` integration owns verified `progbuf0..3` address routing.

## 2. External Contract

| Port | Direction | Required behavior |
| --- | --- | --- |
| `clk_i` | input | Clock for all Program Buffer words |
| `rst_ni` | input | Asynchronous active-low reset clearing every word |
| `clear_i` | input | Synchronous whole-buffer clear with priority over write |
| `write_valid_i` | input | Qualifies one word write on the next rising edge |
| `write_index_i` | input | Selects one of four stored words |
| `write_data_i` | input | 32-bit RV32 instruction payload |
| `read_index_i` | input | Selects the combinational DMI-side read word |
| `read_data_o` | output | Current selected word, without a registered response stage |
| `words_o` | output | Full four-word view reserved for the future executor |

## 3. Functional Requirements

The default `WORD_COUNT` is four. Each word is 32 bits and all words reset to
zero. A valid write updates only the selected word. Non-selected words hold.

Update priority is:

```text
1. rst_ni=0 clears all words asynchronously
2. clear_i=1 clears all words on the rising edge
3. write_valid_i=1 updates words_q[write_index_i]
4. otherwise all words hold
```

`clear_i` and `write_valid_i` may be asserted together; clear must win.

## 4. Unsupported Scope

```text
DMI address routing inside this leaf (provided by debug_dmi_regs integration)
abstractcs.progbufsize advertisement
Access Register postexec behavior
implicit ebreak execution
core instruction injection and exception reporting
```

Those functions must be added and verified together so external debuggers are
never told that Program Buffer execution exists when only storage is present.

## 5. Target Support

The implementation is synthesizable target-neutral SystemVerilog. Generic
simulation, IC, and Xilinx Virtex-7 target macros must preserve identical
storage, reset, clear, and read behavior.
