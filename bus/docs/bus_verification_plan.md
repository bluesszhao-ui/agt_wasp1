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
| 540ns-600ns | Full fabric selected slave stalls HREADY low | Master control remains stable while stalled | TBD |

## 3. Protocol Checks

```text
only one slave select is active per accepted address phase
default slave selected for unmapped regions
granted master receives selected slave response
non-granted master is stalled
address/control stay stable while HREADY is low
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
core priority after reset
DMA grant after core grant
stall insertion on each response path
```
