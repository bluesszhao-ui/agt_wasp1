`timescale 1ns/1ps

// IC synthesis blackbox for `wasp1_otp_macro`.
//
// Use this stub when an ASIC synthesis run must bind executable program storage
// to an OTP/NVM compiler macro. The AHB wrapper above this boundary owns the
// software-visible unlock, lock, status, and illegal 0->1 programming checks.
(* blackbox *)
module wasp1_otp_macro #(
  parameter int DATA_WIDTH = 32,
  parameter int DEPTH = 1024,
  parameter int ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
  input  logic                  clk_i,            // OTP macro/program clock.
  input  logic [ADDR_WIDTH-1:0] read_addr_i,      // Executable/readback word address.
  output logic [DATA_WIDTH-1:0] read_data_o,      // Read data.
  input  logic [ADDR_WIDTH-1:0] prog_addr_i,      // Programming word address.
  input  logic                  prog_i,           // Accepted programming pulse.
  input  logic [DATA_WIDTH-1:0] prog_data_i,      // Programming data.
  output logic [DATA_WIDTH-1:0] prog_read_data_o  // Existing word for legality checks.
);
endmodule
