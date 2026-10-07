# Run with Synopsys VCS from this directory: make vcs
VCS ?= vcs
RUN_ARGS ?= +ntb_random_seed=7
RTL = ../rtl/texture_cache.sv
TB  = ../tb/tb_texture_cache.sv

.PHONY: vcs clean
vcs:
	$(VCS) -full64 -sverilog -assert -timescale=1ns/1ps $(RTL) $(TB) -o simv
	./simv $(RUN_ARGS)

clean:
	rm -rf simv simv.daidir csrc *.log *.vpd *.fsdb
