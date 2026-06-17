# icache Verification Plan

## 1. Goals

Verify the integrated instruction cache using real `icache_ctrl`, `icache_tag`,
`icache_data`, and `icache_refill` instances.

## 2. Testbench Model

`tb_icache` drives the frontend `mem_req_rsp_if` and models the downstream
instruction memory. The memory model checks every refill word request and
returns deterministic data from the requested address.

## 3. Directed Cases

| Case | Purpose | Expected Result |
| --- | --- | --- |
| Basic miss | Empty cache fetch | Four downstream word reads, selected word response |
| Same-word hit | Fetch same address after fill | No downstream request, data returned from cache |
| Same-line hit | Fetch another word in filled line | No downstream request, selected line word returned |
| Backpressure miss | Stall downstream request/response and frontend response | Valid/data/address remain stable |
| Conflict replacement | Fill two addresses mapping to same index | Later tag replaces earlier line |
| Invalid requests | Write, bad size, misaligned, non-instruction | Error response with no downstream request |
| Refill error | One refill beat returns error | Frontend fault and tag remains invalid |
| Error recovery | Refetch after failed refill | New miss refills successfully, then hits |
| Invalidate | Assert `invalidate_i` after a fill | Next access misses and refills |
| Flush abort | Assert `flush_i` during active refill | No stale response, cache recovers on next request |

## 4. Random Checks

A deterministic 16-iteration stream fills a random aligned line and immediately
checks the corresponding hit with varied downstream and frontend stalls.

## 5. Coverage Intent

```text
integrated miss/refill/hit sequence
direct-mapped conflict replacement
tag invalidation
refill error invalid behavior
flush abort recovery
frontend response backpressure
downstream request and response backpressure
deterministic-random fill/hit pairs
```
