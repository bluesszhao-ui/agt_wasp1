# wasp1 Cache and Runtime Metrics

## 1. Command

```text
make -C wasp1 sim-cache-metrics
```

The target builds the `tb_wasp1` Verilator simulation once, runs the generated
OTP images from `llvm_s1`, and writes:

```text
wasp1/logs/cache_metrics.csv
wasp1/logs/cache_metrics.md
```

The log outputs are generated artifacts and are not committed.

## 2. Metric Definitions

| Metric | Definition |
| --- | --- |
| `cycles` | Active `hclk` cycles after reset release until the selected firmware check finishes, including the standard top-level reset/JTAG smoke and idle-stability windows. |
| `retired` | Core architectural retire pulses observed inside `core_int_datapath`. |
| `IPC` | `retired / cycles`. |
| `CPI` | `cycles / retired`. |
| `I-hit %` | I-cache tag hits divided by accepted I-cache frontend requests. |
| `D-hit %` | D-cache tag hits divided by cacheable, aligned D-cache core requests. |
| `I req/hit/miss` | Accepted I-cache requests, tag-hit requests, and refill starts. |
| `D req/cache/uncached/hit/miss` | Accepted D-cache requests, cacheable requests, uncached requests, cacheable tag hits, and cacheable tag misses. |

D-cache stores are write-through. A store can still count as a D-cache tag hit
when the addressed line is already cached, but the write also issues a
downstream store transaction.

## 3. Current Baseline

Observed on the checked-in RTL/testbench with Verilator 5.046:

| Program | Cycles | Retired | IPC | CPI | I-hit % | D-hit % | I req/hit/miss | D req/cache/uncached/hit/miss |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| `hello_uart` | 1706 | 140 | 0.082 | 12.185 | 75.5 | 71.4 | 168/127/41 | 60/56/4/40/16 |
| `long_boot` | 25976 | 2628 | 0.101 | 9.884 | 82.1 | 93.9 | 3222/2647/575 | 1325/1250/75/1174/76 |
| `mixed_irq_dma` | 16604 | 1684 | 0.101 | 9.859 | 82.7 | 87.3 | 2008/1662/346 | 887/852/35/744/108 |
| `system_stress` | 73727 | 9027 | 0.122 | 8.167 | 87.2 | 92.7 | 10904/9519/1385 | 4387/4228/159/3923/305 |
| `random_irq_stress` | 111920 | 9999 | 0.089 | 11.193 | 77.9 | 91.4 | 11745/9161/2584 | 5432/5277/155/4825/452 |
| `dma_copy` | 2100 | 263 | 0.125 | 7.984 | 87.6 | 78.4 | 324/284/40 | 106/102/4/80/22 |
| `dma_irq` | 8266 | 814 | 0.098 | 10.154 | 82.1 | 80.9 | 960/789/171 | 425/410/15/332/78 |
| `gpio_irq` | 8737 | 723 | 0.082 | 12.084 | 75.6 | 80.6 | 830/628/202 | 408/388/20/313/75 |
| `uart_irq` | 7537 | 669 | 0.088 | 11.266 | 78.9 | 78.2 | 776/613/163 | 371/354/17/277/77 |
| `uart_rx_irq` | 14834 | 1322 | 0.089 | 11.220 | 78.4 | 85.4 | 1558/1222/336 | 697/667/30/570/97 |
| `timer_irq` | 4968 | 411 | 0.082 | 12.087 | 77.0 | 68.4 | 471/363/108 | 234/225/9/154/71 |
| `otp_program` | 3203 | 511 | 0.159 | 6.268 | 94.6 | 54.0 | 650/615/35 | 178/174/4/94/80 |

## 4. Interpretation Notes

These are simulation-level microarchitecture counters, not benchmark scores.
The current core is an intentionally small in-order RV32I design and many
programs spend cycles in MMIO polling, UART serialization waits, DMA polling, or
interrupt/trap setup. CPI therefore includes memory-system latency, uncached
MMIO accesses, cache refill latency, and testbench completion waits.
