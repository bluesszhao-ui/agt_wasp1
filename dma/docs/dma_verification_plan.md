# dma Verification Plan

## 1. Goals

Verify `ahb_dma` as the second AHB master and first DMA copy engine.

The first milestone focuses on software-visible register behavior, word copy
sequencing, AHB master read/write behavior, IRQ behavior, error handling, and
target macro compile coverage.

## 2. Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Cycles 0-3 | Apply reset | Slave OKAY, master idle, IRQ low, status clear | PASS |
| Directed | Read reset status | busy/done/error clear | PASS |
| Directed | Program SRC/DST/LEN and start 4-word copy | Destination words match source words | PASS |
| Directed | Registered read response latency | Read data is sampled after the DMA read wait slot | PASS |
| Random | 4 deterministic copy cases | Destination words match source words | PASS |
| Directed | Complete with IRQ enabled | `dma_irq_o` asserts on done | PASS |
| Directed | Clear status | done/error clear | PASS |
| Directed | Start with LEN zero | STATUS.error set | PASS |
| Directed | Start with misaligned source | STATUS.error set | PASS |
| Directed | Inject master read error | STATUS.error set | PASS |
| Directed | Inject master write error | STATUS.error set | PASS |
| Directed | Misaligned, byte, unknown register accesses | HRESP ERROR | PASS |

## 3. Target Compile Matrix

| Target | Macro | Command | Expected result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C dma lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C dma lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C dma lint-fpga-v7` | PASS |

## 4. Coverage Intent

```text
register read path
register write path
start accepted path
start rejected path
AHB master read path
AHB master write path
done IRQ path
master error paths
AHB slave error paths
deterministic random copies
```
