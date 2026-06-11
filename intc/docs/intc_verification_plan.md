# intc Verification Plan

## 1. Goals

Verify `ahb_intc` as the PLIC-lite machine external interrupt controller.

## 2. Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Cycles 0-3 | Apply reset | HREADY high, HRESP OKAY, MEIP low, claim ID zero | PASS |
| Directed | Read reset registers | Pending/enable/threshold clear, source priorities initialized | PASS |
| Directed | Drive IRQ2 while disabled | Pending captures, MEIP remains low | PASS |
| Directed | Enable IRQ2 | MEIP asserts, claim returns 2 | PASS |
| Directed | Complete IRQ2 | Pending clears after source drops | PASS |
| Directed | Configure priorities for IRQ2/4/5 | Highest priority source is claimed | PASS |
| Directed | Raise threshold | Sources at or below threshold are masked | PASS |
| Directed | Equal priority IRQ1/3 | Lower source ID wins | PASS |
| Directed | Source ID0 activity | ID0 is ignored | PASS |
| Directed | W1C pending clear | Selected pending bit clears | PASS |
| Random | 8 deterministic source combinations | Claim returns expected lowest enabled pending source | PASS |
| Directed | Misaligned, byte, unknown, invalid priority, out-of-range accesses | HRESP ERROR | PASS |

## 3. Target Compile Matrix

| Target | Macro | Command | Expected result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C intc lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C intc lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C intc lint-fpga-v7` | PASS |

## 4. Coverage Intent

```text
pending capture
enable masking
priority selection
tie-break
threshold masking
claim read
complete write
W1C pending clear
ID0 ignored
AHB error paths
deterministic random source combinations
```
