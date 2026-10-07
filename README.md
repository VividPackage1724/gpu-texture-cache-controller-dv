# GPU Texture Cache Controller Verification

An educational SystemVerilog verification project for a small, read-only, direct-mapped texture-cache controller. It is designed to demonstrate RTL reasoning, protocol verification, cache hit/miss behavior, assertions, scoreboarding, and constrained/random-style stimulus in a GPU hardware verification interview.

> This is an original simplified learning design, not proprietary GPU RTL or a claim of production GPU cache verification experience.

## Feature summary
- 32-bit word reads over a valid/ready CPU interface.
- Four direct-mapped lines, 16 bytes per line (64-byte capacity).
- Line refill through a simplified 128-bit memory response interface.
- Hit/miss handling, conflict replacement, reset invalidation.
- Stable response under backpressure.
- Self-checking directed and randomized testbench with backing-memory oracle.
- SystemVerilog Assertions for protocol stability.

## Repository map
- `rtl/texture_cache.sv` — cache controller RTL.
- `tb/tb_texture_cache.sv` — memory model and self-checking testbench.
- `docs/feature_spec.md` — exact functional/protocol contract.
- `docs/verification_plan.md` — test matrix and exit criteria.
- `docs/architecture.md` — FSM and proposed UVM decomposition.
- `sim/Makefile` — VCS compile/run target.
- `scripts/run_regression.sh` — regression wrapper.
- `results/regression_summary.md` — intentionally marked not run until VCS execution.

## Run with VCS
Requirements: Synopsys VCS with SystemVerilog and assertion support.

```bash
cd sim
make vcs
# or from repository root
./scripts/run_regression.sh
```

The testbench runs directed cold-miss/hit/word-select/conflict/backpressure/reset tests followed by 100 randomized aligned reads. The backing-memory oracle is independent of the DUT's internal cache arrays.

## Important status note
The authoring environment used to assemble this repository does not have VCS installed, so simulation results are **not yet verified**. Run the regression in VCS and update `results/regression_summary.md` with actual results before presenting it as passing.

## Suggested next milestones
1. Run the baseline under VCS and fix any compile/runtime issues.
2. Split the testbench into UVM agents, sequences, monitor, scoreboard, and coverage.
3. Add covergroups and coverage closure review.
4. Perform mutation testing: inject an incorrect tag compare, wrong word select, or missing valid-bit reset and confirm the tests detect each bug.
5. Add CI lint/compile automation if your environment supports it.
