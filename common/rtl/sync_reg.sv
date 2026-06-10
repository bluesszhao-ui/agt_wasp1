module sync_reg #(
  parameter int WIDTH  = 1,
  parameter int STAGES = 2
) (
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic [WIDTH-1:0] async_i,
  output logic [WIDTH-1:0] sync_o
);
  logic [STAGES-1:0][WIDTH-1:0] sync_q;

  integer stage;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sync_q <= '0;
    end else begin
      sync_q[0] <= async_i;
      for (stage = 1; stage < STAGES; stage = stage + 1) begin
        sync_q[stage] <= sync_q[stage-1];
      end
    end
  end

  assign sync_o = sync_q[STAGES-1];
endmodule
