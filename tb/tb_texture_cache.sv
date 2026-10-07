`timescale 1ns/1ps
module tb_texture_cache;
  localparam int LINE_BYTES = 16;
  localparam int WORDS_PER_LINE = 4;
  logic clk = 0;
  always #5 clk = ~clk;
  logic rst_n;
  logic req_valid, req_ready;
  logic [31:0] req_addr;
  logic rsp_valid, rsp_ready;
  logic [31:0] rsp_data;
  logic mem_req_valid, mem_req_ready;
  logic [31:0] mem_req_addr;
  logic mem_rsp_valid, mem_rsp_ready;
  logic [127:0] mem_rsp_data;

  logic [31:0] backing_mem [logic [31:0]];
  int mem_read_count = 0;
  int pass_count = 0;
  int fail_count = 0;
  int unsigned random_seed = 32'h71CA_C4E5;

  texture_cache dut (.*);

  // One outstanding memory transaction, with programmable pseudo-random delay.
  typedef enum logic [1:0] {M_IDLE, M_DELAY, M_RETURN} mem_state_t;
  mem_state_t mem_state;
  int delay_count;
  logic [31:0] held_mem_addr;
  integer lane;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_state <= M_IDLE;
      mem_req_ready <= 1'b0;
      mem_rsp_valid <= 1'b0;
      mem_rsp_data <= '0;
      delay_count <= 0;
      held_mem_addr <= '0;
    end else begin
      mem_req_ready <= 1'b0;
      mem_rsp_valid <= 1'b0;
      case (mem_state)
        M_IDLE: begin
          if (mem_req_valid) begin
            mem_req_ready <= 1'b1;
            held_mem_addr <= mem_req_addr;
            delay_count <= $urandom(random_seed) % 4;
            mem_read_count <= mem_read_count + 1;
            mem_state <= M_DELAY;
          end
        end
        M_DELAY: begin
          if (delay_count == 0) begin
            for (lane = 0; lane < WORDS_PER_LINE; lane++)
              mem_rsp_data[lane*32 +: 32] <= backing_mem[held_mem_addr + lane*4];
            mem_state <= M_RETURN;
          end else delay_count <= delay_count - 1;
        end
        M_RETURN: begin
          if (mem_rsp_ready) begin
            mem_rsp_valid <= 1'b1;
            mem_state <= M_IDLE;
          end
        end
        default: mem_state <= M_IDLE;
      endcase
    end
  end

  task automatic check_word(input logic [31:0] addr, input logic [31:0] expected, input string label);
    logic [31:0] actual;
    int timeout_cycles;
    begin
      @(negedge clk);
      req_addr = addr;
      req_valid = 1'b1;
      timeout_cycles = 0;
      while (req_ready !== 1'b1) begin
        @(negedge clk); timeout_cycles++;
        if (timeout_cycles > 200) $fatal(1, "timeout accepting request %s", label);
      end
      @(posedge clk); // handshake occurs on this edge
      @(negedge clk); req_valid = 1'b0;
      timeout_cycles = 0;
      while (!rsp_valid) begin
        @(negedge clk); timeout_cycles++;
        if (timeout_cycles > 200) $fatal(1, "timeout waiting response %s", label);
      end
      actual = rsp_data;
      if (actual !== expected) begin
        fail_count++;
        $error("FAIL %s addr=%08h expected=%08h actual=%08h", label, addr, expected, actual);
      end else begin
        pass_count++;
        $display("PASS %s addr=%08h data=%08h", label, addr, actual);
      end
      @(negedge clk); rsp_ready = 1'b1;
      @(posedge clk);
      @(negedge clk); rsp_ready = 1'b0;
    end
  endtask

  function automatic logic [31:0] expected_word(input logic [31:0] addr);
    expected_word = backing_mem[addr & 32'hFFFF_FFFC];
  endfunction

  initial begin
    rst_n = 0; req_valid = 0; req_addr = 0; rsp_ready = 0;
    // Deterministic backing memory pattern makes stale/conflict errors obvious.
    for (int a = 0; a < 4096; a += 4)
      backing_mem[a] = 32'hA500_0000 ^ (a * 32'h1021) ^ (a >> 2);
    repeat (4) @(negedge clk);
    rst_n = 1;
    repeat (2) @(negedge clk);

    // Cold miss, same-line hit, and another word in the same line.
    check_word(32'h0000_0040, expected_word(32'h40), "cold_miss");
    check_word(32'h0000_0040, expected_word(32'h40), "same_address_hit");
    check_word(32'h0000_004C, expected_word(32'h4C), "same_line_word_hit");

    // Same index, different tag: must evict and return new line's data.
    check_word(32'h0000_0080, expected_word(32'h80), "conflict_miss");
    check_word(32'h0000_0040, expected_word(32'h40), "conflict_revisit_miss");

    // Response backpressure: hold ready low and ensure valid/data are stable.
    @(negedge clk); req_addr = 32'h0000_0100; req_valid = 1;
    while (req_ready !== 1'b1) @(negedge clk);
    @(posedge clk); // request handshake
    @(negedge clk); req_valid = 0;
    wait (rsp_valid);
    begin
      logic [31:0] held_data;
      held_data = rsp_data;
      repeat (5) begin
        @(negedge clk);
        if (!rsp_valid || rsp_data !== held_data) $fatal(1, "response not stable under backpressure");
      end
      if (held_data !== expected_word(32'h100)) $fatal(1, "backpressure test data mismatch");
      pass_count++;
    end
    @(negedge clk); rsp_ready = 1;
    @(posedge clk); @(negedge clk); rsp_ready = 0;

    // Randomized address stream, checking every response against backing memory.
    repeat (100) begin
      logic [31:0] addr;
      addr = ($urandom(random_seed) % 1024) & 32'hFFFF_FFFC;
      check_word(addr, expected_word(addr), "random_read");
    end

    // Reset must invalidate tags; next access is expected to cause a miss.
    @(negedge clk); rst_n = 0;
    repeat (3) @(negedge clk);
    rst_n = 1;
    repeat (2) @(negedge clk);
    begin
      int reads_before;
      reads_before = mem_read_count;
      check_word(32'h0000_0040, expected_word(32'h40), "post_reset_miss");
      if (mem_read_count <= reads_before) $fatal(1, "cache did not miss after reset");
      pass_count++;
    end

    $display("\nSUMMARY: PASS=%0d FAIL=%0d MEMORY_READS=%0d", pass_count, fail_count, mem_read_count);
    if (fail_count != 0) $fatal(1, "testbench failures detected");
    $finish;
  end
endmodule
