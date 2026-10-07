# Architecture and Verification Environment

## RTL state machine
`IDLE -> LOOKUP -> RESP` on a hit. On a miss: `IDLE -> LOOKUP -> MEM_REQ -> MEM_WAIT -> RESP -> IDLE`.

- `IDLE`: accept one CPU request and latch its address.
- `LOOKUP`: compare valid bit and tag; choose hit response or start refill.
- `MEM_REQ`: hold aligned line address until memory accepts it.
- `MEM_WAIT`: wait for a complete line response and install it.
- `RESP`: hold response data/valid until consumed.

## Reference testbench
`tb/tb_texture_cache.sv` instantiates the DUT and a simple delayed backing-memory model. The testbench owns the golden backing-memory array and compares all returned words against it. It includes directed hit/miss/conflict/reset tests, response backpressure, and randomized aligned reads.

## Recommended UVM evolution
For a full UVM portfolio version, split the monolithic reference testbench into:
- `cpu_read_if`: request/response interface and clocking blocks.
- `cpu_read_agent`: sequencer, driver, monitor, and agent configuration.
- `memory_agent`: randomized-latency line responder.
- `cache_scoreboard`: reference memory plus transaction-level checking.
- `cache_coverage`: covergroups for hit/miss, index, word offset, conflict, latency, and backpressure.
- `cache_virtual_sequencer` and virtual sequences for reset, conflict, and stress scenarios.

The included self-checking testbench is intentionally the first executable milestone. UVM classes are not included yet so the baseline can be reviewed independently before layering in the UVM environment.
