# bus Verification Plan

## 1. Goals

The bus verification plan checks AHB-Lite arbitration, address decoding, slave
response muxing, and default error handling.

## 2. Directed Cases

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-20ns | Apply reset | Arbiter grant and decoder state reset | TBD |
| 20ns-60ns | Decode OTP/I-SRAM/D-SRAM base/mid/end addresses | Matching memory select asserted | PASS for `ahb_decoder` |
| 60ns-100ns | Decode peripheral base/mid/end addresses | Matching peripheral select asserted | PASS for `ahb_decoder` |
| 100ns-140ns | DMA reads D-SRAM address | DMA receives grant and slave response | TBD |
| 140ns-200ns | Core and DMA request simultaneously | Round-robin alternates accepted grants | TBD |
| 200ns-240ns | Access unmapped and boundary addresses | Default slave selected | PASS for `ahb_decoder` |
| 240ns-300ns | Default slave handles selected valid transfers | HRESP ERROR, HREADY high, HRDATA zero | PASS for `ahb_default_slave` |
| 300ns-360ns | Default slave handles idle, busy, and unselected transfers | HRESP OKAY, HREADY high, HRDATA zero | PASS for `ahb_default_slave` |
| 360ns-420ns | Slave mux selects each slave response | Selected HRDATA/HREADY/HRESP forwarded | PASS for `ahb_slave_mux` |
| 420ns-480ns | Slave mux handles no-select and multi-select cases | No-select OKAY, multi-select ERROR | PASS for `ahb_slave_mux` |
| 480ns-540ns | Selected slave stalls HREADY low | Master sees HREADY low from selected slave | PASS for `ahb_slave_mux` |
| 540ns-640ns | Arbiter handles single-master requests | Requesting master granted and response routed | PASS for `ahb_arbiter_2m` |
| 640ns-760ns | Arbiter handles simultaneous requests | Grants alternate round-robin | PASS for `ahb_arbiter_2m` |
| 760ns-840ns | Arbiter sees downstream HREADY low in WAIT/RESP | Owner remains stalled and write data remains stable | PASS for `ahb_arbiter_2m` |
| 840ns-940ns | Arbiter holds write data after write address phase | HWDATA remains from transaction owner through WAIT | PASS for `ahb_arbiter_2m` |
| 940ns-1040ns | Fabric routes m0/m1 to external slaves | Correct slave select and response routing | PASS for `ahb_fabric_2m` |
| 1040ns-1140ns | Fabric handles unmapped address | No external select, default ERROR response | PASS for `ahb_fabric_2m` |
| 1140ns-1240ns | Full fabric selected slave stalls HREADY low | Master observes HREADY low, then completes | PASS for `ahb_fabric_2m` |

## 3. Protocol Checks

```text
only one slave select is active per accepted address phase
default slave selected for unmapped regions
granted master receives selected slave response
non-granted master is stalled
address/control are emitted only in ADDR; HWDATA remains stable through WAIT
round-robin grant toggles under simultaneous valid requests
```

`ahb_decoder` additionally checks:

```text
active_i low selects no slave
active_i high produces exactly one hot hsel bit
each slave is selected at least once
default path is selected by multiple unmapped addresses
deterministic random addresses match the scoreboard model
```

`ahb_default_slave` additionally checks:

```text
unselected transfers return OKAY
selected IDLE/BUSY transfers return OKAY
selected NONSEQ/SEQ transfers return ERROR
HREADY is always high
HRDATA is always zero
read and write controls do not change response policy
byte/halfword/word sizes do not change response policy
deterministic random cases match the scoreboard model
```

`ahb_slave_mux` additionally checks:

```text
no-select response
every slave selected at least once
selected HRDATA/HREADY/HRESP forwarding
selected HREADY low forwarding
selected HRESP ERROR forwarding
multi-select select_err_o and ERROR response
deterministic random one-hot response forwarding
```

`ahb_arbiter_2m` additionally checks:

```text
reset no-grant state
single m0 request grant
single m1 request grant
simultaneous request round-robin alternation
WAIT/RESP HREADY low transaction-owner hold
write-data hold through registered slave data phase
selected master response routing
non-selected requesting master held with HREADY low
```

`ahb_fabric_2m` additionally checks:

```text
integrated reset no-grant/no-select state
m0 route through decoder/mux to OTP mock slave
m1 route through decoder/mux to D-SRAM mock slave
unmapped route to internal default slave
external slave HREADY low propagation
round-robin integration across two masters
write-data hold through fabric wait phase
```

## 4. Coverage Intent

Functional coverage should include:

```text
each slave selected at least once
base/mid/end point per slave
before/after boundary point per slave when applicable
read and write transfer per writable slave
default error path
default slave OKAY and ERROR paths
default slave byte/halfword/word sizes
default slave read/write paths
slave mux no-select and multi-select paths
slave mux every slave response path
slave mux HREADY low and HRESP ERROR paths
arbiter m0-only and m1-only grants
arbiter simultaneous request alternation
arbiter WAIT/RESP stall hold
arbiter write-data hold
arbiter response routing and error path
fabric external slave routing
fabric default error routing
fabric selected slave stall propagation
core priority after reset
DMA grant after core grant
stall insertion on each response path
```
