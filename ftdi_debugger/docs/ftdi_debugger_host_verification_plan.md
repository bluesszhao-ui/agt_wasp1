# ftdi_debugger Host Verification Plan

## 1. Goals

Verify byte-exact framing, corruption rejection, request/response matching,
chunking, geometry checks, irreversible-bit safety, explicit destructive CLI
confirmation, and platform collateral before running on physical OTP.

## 2. Automated Cases

| Area | Stimulus | Pass criteria |
| --- | --- | --- |
| Frame round trip | Encode/decode request and error response | Every field and payload is preserved |
| CRC rejection | Flip one header byte | Decode rejects the frame before dispatch |
| Length rejection | Truncate and oversize frames | Decode rejects both boundaries |
| Probe | Model returns `OTP_DATA_SIZE`, capabilities, and chunk limit | Client reports exact geometry |
| Chunked read | Read 20 bytes with 8-byte target limit | Requests are 8, 8, and 4 bytes |
| Program and verify | Program a 12-byte image with 8-byte target limit | Pre-read, 8/4-byte writes, and full readback pass |
| Monotonic safety | Request one `0 -> 1` transition | Client sends no PROGRAM command |
| Alignment | Use unaligned offset and length | Client rejects both locally |
| Range | Cross target OTP end | Client sends no READ/PROGRAM command |
| Target error | Model is locked | Error names LOCKED and request offset |
| Sequence | Return wrong response sequence | Client rejects the response |
| Lock/status | Lock model and read STATUS | Hardware lock bit 3 is observed |
| Port selection | Model one Windows VCP, explicit Linux Interface B, and ambiguous devices | Unique/explicit Channel B is selected; ambiguity requires `--port` |
| RV32I image | Link loader at `0x1000_0000` | ELF/bin fit I-SRAM and have no libc dependency |
| SoC UART/OTP | Execute loader in I-SRAM and send 8N1 frames | HELLO, program, read, CRC error, transition error, lock, and locked rejection pass |

## 3. Time-Sequenced Action Table

| Time | Action | Expected result |
| --- | --- | --- |
| 0ms-10ms | Run protocol encode/decode tests | valid request and response frames round-trip |
| 10ms-20ms | Corrupt CRC and frame lengths | malformed frames are rejected |
| 20ms-30ms | Probe in-memory loader model | geometry and capability fields match |
| 30ms-40ms | Run chunked read | request boundaries match target limit |
| 40ms-50ms | Pre-read, program, and verify image | monotonic image is written and read back |
| 50ms-60ms | Attempt illegal bit transition | no PROGRAM command reaches the model |
| 60ms-70ms | Exercise alignment and range errors | invalid requests are rejected locally |
| 70ms-80ms | Exercise target LOCKED and sequence errors | errors retain protocol context |
| 80ms-90ms | Lock and read hardware status model | lock bit is set and remains visible |

## 4. Physical Follow-Up

The target I-SRAM loader now passes complete-SoC simulation. After board
assembly, repeat the cases through FT2232H Channel B and add UART line
corruption, cable disconnect, response-loss retry, power interruption,
wrong-interface selection, multiple-debugger selection, and maximum-image tests.
No physical LOCK operation is permitted until a disposable sample and image
release checklist are explicitly approved.
