# debug_dmi_if Design Spec

## 1. Scope

`debug_dmi_if` contains signals and modports only. It contains no storage,
state machine, combinational logic, or clocked process.

## 2. Editable Connectivity Diagram

editable source: `debug/docs/diagrams/debug_dmi_if_connectivity.graffle`
preview export: none
detail level: L2
clock domains: none inside the interface declaration

The editable OmniGraffle diagram shows the `dtm`, `dm`, and `monitor` modports
as `IF` timing-class blocks because the interface declaration contains no
storage, state machine, combinational process, or clocked process. All
sequential buffering is implemented by the connected DTM or DM modules, not by
the interface declaration.

## 3. Modports

`dtm` assigns requester and response-consumer directions. `dm` assigns
request-consumer and response-producer directions. `monitor` is passive and is
intended for assertions, scoreboards, and waveform inspection.

## 4. Target Behavior

The interface is target-neutral and has identical behavior for IC, Xilinx
Virtex-7 FPGA, and generic simulation builds.
