# icache_ctrl Verification Plan

## 1. Goals

Verify that `icache_ctrl` correctly sequences frontend requests, cache lookup
results, refill starts, refill completion updates, responses, faults, flushes,
and backpressure.

## 2. Testbench Model

`tb_icache_ctrl` drives `front_if` as a frontend initiator model and drives mock
tag/data/refill responses. It checks all DUT outputs at handshake boundaries and
uses deterministic reference functions for cache-line construction and refill
word selection.

## 3. Directed Cases

| Case | Purpose | Expected Result |
| --- | --- | --- |
| Basic hit | Legal request with `tag_hit_i=1` | Response returns `data_word_i`, no refill |
| Hit response backpressure | Hold `front_if.rsp_ready=0` | Response remains stable |
| Invalid write | Fetch request marked write | Error response, no refill/update |
| Invalid size | Non-word fetch request | Error response, no refill/update |
| Invalid alignment | `addr[1:0] != 0` | Error response, no refill/update |
| Invalid instruction flag | `req_instr=0` | Error response, no refill/update |
| Basic miss | Legal miss and refill completion | One refill start, one update, selected word response |
| Refill start backpressure | Hold `refill_start_ready_i=0` | Start valid/address remain stable |
| Refill error | Completed line has error | Tag update error and response error asserted |
| Flush abort | Flush active miss after start | No response/update, controller returns idle |
| Post-flush recovery | New hit after flush | Normal response |

## 4. Random Checks

A deterministic 24-transaction stream mixes hits, misses, refill errors,
invalid requests, refill start stalls, and response stalls.

## 5. Coverage Intent

```text
FSM states: CTRL_IDLE, CTRL_MISS_REQ, CTRL_MISS_WAIT, CTRL_RESP
request classes: hit, miss, invalid
invalid classes: write, size, alignment, instruction flag
handshakes: frontend request/response, refill start, refill line
error paths: invalid request, refill error
abort path: flush during outstanding miss
backpressure: response hold and refill start hold
```
