# Verification Plan

## Test objectives
- Validate request/response handshakes and single-outstanding behavior.
- Validate hit, miss, refill, word selection, tag/index/offset decoding, and conflict replacement.
- Validate stable payload under response backpressure.
- Validate reset invalidation and memory-request alignment.
- Stress random addresses and randomized memory latency against an independent backing-memory oracle.

## Directed tests
| Test | Stimulus | Expected result |
|---|---|---|
| cold_miss | Read an address after reset | One line request; correct word returned |
| same_address_hit | Read same address again | Correct data; no additional line request |
| same_line_word_hit | Read another word in a filled line | Correct word; no additional line request |
| conflict_miss | Read a different tag with the same index | Miss, replacement, correct new data |
| conflict_revisit_miss | Re-read evicted address | Miss and correct refill |
| response_backpressure | Hold `rsp_ready=0` after response appears | `rsp_valid` and `rsp_data` remain stable |
| random_read | 100 pseudo-random aligned reads | Every response matches backing memory |
| post_reset_miss | Reset after cache has been used, then re-read | Line is invalidated and refetched |

## Assertions
- Response valid/data stable while backpressured.
- Memory request valid/address stable until accepted.
- Request acceptance is structurally restricted to IDLE.

## Scoreboard/oracle strategy
The testbench's backing-memory array is the source of expected data. Each CPU response is compared against the expected word indexed by the aligned byte address. The DUT cache arrays are never read by the checker, avoiding circular checking.

## Coverage to add in UVM extension
- Hit/miss outcome.
- Each cache index and each word offset.
- Same-index/different-tag conflict sequence.
- Memory wait latency bins (0, 1–2, 3+ cycles).
- Response backpressure duration bins (0, 1–2, 3+ cycles).
- Reset while idle and reset after prior traffic.

## Exit criteria
- All directed and random tests pass with zero scoreboard mismatches.
- No assertion failures.
- Coverage goals are reviewed and justified; no claim of signoff completeness is made for this educational design.
