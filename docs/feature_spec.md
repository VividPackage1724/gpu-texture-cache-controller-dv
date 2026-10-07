# Feature Specification — Texture Cache Controller (v1)

## Purpose
An educational GPU-adjacent verification target: a small read-only texture-cache controller. This is an original simplified design for portfolio and interview practice, not a reproduction of any proprietary GPU microarchitecture.

## Parameters and organization
- Address width: 32 bits.
- CPU data width: 32 bits; reads must be 4-byte aligned.
- Cache organization: direct mapped, 4 lines, 16 bytes (4 words) per line.
- Capacity: 64 bytes.
- Index: address bits `[5:4]`.
- Byte offset: address bits `[3:0]`.
- Tag: address bits `[31:6]`.
- Backing-memory response: one complete 128-bit cache line, with word 0 in bits `[31:0]` and word 3 in `[127:96]`.

## CPU-side protocol
A request is accepted on a rising clock edge when `req_valid && req_ready` are both high. The controller accepts only one request at a time. `req_ready` is high only in the IDLE state. Each accepted request eventually produces exactly one response. A response is consumed on a rising edge with `rsp_valid && rsp_ready`. While `rsp_valid && !rsp_ready`, `rsp_valid` and `rsp_data` must remain stable.

## Memory-side protocol
`mem_req_valid` and `mem_req_addr` remain asserted/stable until a rising edge where `mem_req_ready` is high. `mem_req_addr` is aligned down to a 16-byte boundary. The memory returns one 128-bit line using `mem_rsp_valid` and `mem_rsp_data`; the cache accepts it when `mem_rsp_valid && mem_rsp_ready` are high. The memory model must hold response data/valid stable until accepted.

## Functional behavior
1. Reset invalidates all cache lines; it does not reset backing memory.
2. On a hit, return the selected 32-bit word and do not issue a memory request.
3. On a miss, request the aligned line, wait for the response, install the returned line and tag, then return the requested word.
4. Two addresses with equal index but different tags conflict and replace one another.
5. No CPU request is accepted while a prior request is being processed or its response is pending.
6. No writes, byte enables, coherence, prefetch, multiple outstanding requests, or memory-error path are included in v1.

## Assumptions and limitations
- CPU addresses are word aligned. Misaligned requests are outside the contract and are not checked in v1.
- The memory model is reliable and eventually responds.
- This is a compact verification exercise, not a performance-accurate GPU cache or production IP.
