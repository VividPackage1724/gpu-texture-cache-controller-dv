timescale 1ns/1ps

// Educational, single-outstanding-read, direct-mapped texture-cache model.
// 4 lines x 16 bytes/line. CPU requests are aligned 32-bit word reads.
module texture_cache #(
  parameter int ADDR_W = 32,
  parameter int DATA_W = 32,
  parameter int LINE_BYTES = 16,
  parameter int NUM_LINES = 4
) (
  input  logic                    clk,
  input  logic                    rst_n,

  input  logic                    req_valid,
  output logic                    req_ready,
  input  logic [ADDR_W-1:0]       req_addr,

  output logic                    rsp_valid,
  input  logic                    rsp_ready,
  output logic [DATA_W-1:0]       rsp_data,

  output logic                    mem_req_valid,
  input  logic                    mem_req_ready,
  output logic [ADDR_W-1:0]       mem_req_addr,
  input  logic                    mem_rsp_valid,
  output logic                    mem_rsp_ready,
  input  logic [LINE_BYTES*8-1:0] mem_rsp_data
);
  localparam int WORD_BYTES = DATA_W / 8;
  localparam int WORDS_PER_LINE = LINE_BYTES / WORD_BYTES;
  localparam int INDEX_W = $clog2(NUM_LINES);
  localparam int OFFSET_W = $clog2(LINE_BYTES);
  localparam int TAG_W = ADDR_W - INDEX_W - OFFSET_W;

  typedef enum logic [2:0] {IDLE, LOOKUP, MEM_REQ, MEM_WAIT, RESP} state_t;
  state_t state_q;

  logic [ADDR_W-1:0] request_addr_q;
  logic [DATA_W-1:0] response_data_q;
  logic [NUM_LINES-1:0] valid_q;
  logic [TAG_W-1:0] tag_q [NUM_LINES];
  logic [LINE_BYTES*8-1:0] line_q [NUM_LINES];

  logic [INDEX_W-1:0] request_index;
  logic [TAG_W-1:0] request_tag;
  logic [OFFSET_W-1:0] request_offset;
  logic [DATA_W-1:0] selected_word;
  logic hit;
  integer i;

  always_comb begin
    request_index  = request_addr_q[OFFSET_W +: INDEX_W];
    request_tag    = request_addr_q[ADDR_W-1 -: TAG_W];
    request_offset = request_addr_q[OFFSET_W-1:0];
    selected_word  = '0;
    // Word offsets are 4-byte aligned. Part-select is indexed from the
    // least-significant byte of the 128-bit line.
    selected_word = line_q[request_index][(request_offset / WORD_BYTES)*DATA_W +: DATA_W];
    hit = valid_q[request_index] && (tag_q[request_index] == request_tag);

    req_ready     = (state_q == IDLE);
    rsp_valid     = (state_q == RESP);
    rsp_data      = response_data_q;
    mem_req_valid = (state_q == MEM_REQ);
    mem_req_addr  = request_addr_q & ~(LINE_BYTES - 1);
    mem_rsp_ready = (state_q == MEM_WAIT);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q          <= IDLE;
      request_addr_q   <= '0;
      response_data_q  <= '0;
      valid_q          <= '0;
      for (i = 0; i < NUM_LINES; i++) begin
        tag_q[i]  <= '0;
        line_q[i] <= '0;
      end
    end else begin
      case (state_q)
        IDLE: begin
          if (req_valid && req_ready) begin
            request_addr_q <= req_addr;
            state_q        <= LOOKUP;
          end
        end
        LOOKUP: begin
          if (hit) begin
            response_data_q <= selected_word;
            state_q         <= RESP;
          end else begin
            state_q <= MEM_REQ;
          end
        end
        MEM_REQ: begin
          if (mem_req_valid && mem_req_ready)
            state_q <= MEM_WAIT;
        end
        MEM_WAIT: begin
          if (mem_rsp_valid && mem_rsp_ready) begin
            line_q[request_index] <= mem_rsp_data;
            tag_q[request_index]  <= request_tag;
            valid_q[request_index] <= 1'b1;
            response_data_q <= mem_rsp_data[(request_offset / WORD_BYTES)*DATA_W +: DATA_W];
            state_q <= RESP;
          end
        end
        RESP: begin
          if (rsp_valid && rsp_ready)
            state_q <= IDLE;
        end
        default: state_q <= IDLE;
      endcase
    end
  end

\`ifndef SYNTHESIS
  // Protocol checks. A request is accepted only in IDLE and the response
  // payload must remain stable until the consumer accepts it.
  property p_response_stable_under_backpressure;
    @(posedge clk) disable iff (!rst_n)
      rsp_valid && !rsp_ready |=> rsp_valid && $stable(rsp_data);
  endproperty
  assert property (p_response_stable_under_backpressure)
    else $error("response changed while backpressured");

  property p_memory_request_stable_until_accepted;
    @(posedge clk) disable iff (!rst_n)
      mem_req_valid && !mem_req_ready |=> mem_req_valid && $stable(mem_req_addr);
  endproperty
  assert property (p_memory_request_stable_until_accepted)
    else $error("memory request changed before acceptance");

  property p_no_cpu_accept_while_busy;
    @(posedge clk) disable iff (!rst_n)
      !req_ready |-> ! (req_valid && req_ready);
  endproperty
  assert property (p_no_cpu_accept_while_busy)
    else $error("request accepted while busy");
\`endif
endmodule
