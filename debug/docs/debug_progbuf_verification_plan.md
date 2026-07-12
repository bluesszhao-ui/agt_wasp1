# debug_progbuf Verification Plan

## 1. Scope

Verify the four-word storage leaf independently from DMI and core execution.

## 2. Test Cases

| Case | Action | Expected result |
| --- | --- | --- |
| Asynchronous reset | Hold `rst_ni=0` for three clocks | All selected and parallel word views are zero |
| Directed writes | Write a distinct pattern to each index | Every word updates independently; other words hold |
| Read selection | Select every index after each phase | `read_data_o` and matching `words_o` entry equal the model |
| Clear priority | Assert clear and write together | Every word clears; write payload is discarded |
| Random scoreboard | Perform 64 deterministic-random index/data writes | DUT matches the four-word software model after every write |
| Idle hold | Leave clear/write low between transactions | Stored words remain stable |

## 3. Coverage Goals

```text
both reset mechanisms observed
all four indices written and read
clear-over-write priority observed
at least 64 deterministic-random writes
full-array comparison after every random operation
```

## 4. Target Matrix

| Target | Command | Expected result |
| --- | --- | --- |
| Generic lint | `make -C debug lint-progbuf` | PASS |
| IC lint | `make -C debug lint-progbuf-ic` | PASS |
| Virtex-7 lint | `make -C debug lint-progbuf-fpga-v7` | PASS |
| Functional simulation | `make -C debug sim-progbuf` | PASS |
