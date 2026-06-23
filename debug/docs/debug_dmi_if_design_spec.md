# debug_dmi_if Design Spec

## 1. Scope

`debug_dmi_if` contains signals and modports only. It contains no storage,
state machine, combinational logic, or clocked process.

## 2. Connectivity

```text
 +----------------------+                       +----------------------+
 | IF JTAG DTM          | req_valid/op/addr/data| IF Debug Module      |
 | modport=dtm          |---------------------->| modport=dm           |
 | clk / rst_n          |<----------------------| clk / rst_n          |
 |                      | req_ready             |                      |
 |                      |                       |                      |
 |                      |<----------------------| rsp_valid/resp/data  |
 |                      |---------------------->| rsp_ready            |
 +----------------------+                       +----------------------+
               \                                  /
                +------ IF monitor modport -------+
```

All sequential buffering is implemented by the connected DTM or DM modules,
not by the interface declaration.

## 3. Modports

`dtm` assigns requester and response-consumer directions. `dm` assigns
request-consumer and response-producer directions. `monitor` is passive and is
intended for assertions, scoreboards, and waveform inspection.

## 4. Target Behavior

The interface is target-neutral and has identical behavior for IC, Xilinx
Virtex-7 FPGA, and generic simulation builds.
