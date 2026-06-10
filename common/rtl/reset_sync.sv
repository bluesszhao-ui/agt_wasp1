module reset_sync #(
  parameter int STAGES = 2
) (
  input  logic clk_i,
  input  logic arst_ni,
  output logic srst_no
);
  logic [STAGES-1:0] sync_q;

  initial begin
    sync_q  = '0;
    srst_no = 1'b0;
  end

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      sync_q  <= '0;
      srst_no <= 1'b0;
    end else begin
      sync_q  <= {sync_q[STAGES-2:0], 1'b1};
      srst_no <= sync_q[STAGES-1];
    end
  end
endmodule
