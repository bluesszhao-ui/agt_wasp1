`timescale 1ns/1ps

// Load/store request formatting helper.
//
// This module is combinational. It calculates the effective address, detects
// misalignment, formats store data/byte strobes, and sign/zero-extends load
// response data. Pipeline handshake state lives outside this helper.
module core_lsu (
  input  logic [31:0]                  base_i,       // Base address, normally rs1.
  input  logic [31:0]                  imm_i,        // Sign-extended load/store immediate.
  input  logic [31:0]                  store_data_i, // Raw rs2 store data before lane shifting.
  input  core_types_pkg::core_lsu_size_e size_i,     // Byte, halfword, or word access size.
  input  logic                         unsigned_i,   // Selects zero-extension for byte/half loads.
  input  logic                         load_i,       // Load request qualifier.
  input  logic                         store_i,      // Store request qualifier.
  input  logic [31:0]                  rsp_rdata_i,  // Raw 32-bit memory response data.
  input  logic                         rsp_err_i,    // Downstream memory response error.

  output logic                         req_valid_o,  // Memory request valid, suppressed on misalign.
  output logic [31:0]                  req_addr_o,   // Effective byte address.
  output logic                         req_write_o,  // Store request indicator.
  output logic [1:0]                   req_size_o,   // Memory access size encoding.
  output logic [31:0]                  req_wdata_o,  // Store data aligned to target byte lanes.
  output logic [3:0]                   req_wstrb_o,  // Store byte lane enables.

  output logic [31:0]                  load_data_o,  // Formatted load result for writeback.
  output logic                         misaligned_o, // Alignment fault for selected access size.
  output logic                         fault_o       // Combined misalignment or response fault.
);
  import core_types_pkg::*;

  logic [31:0] addr;      // Effective address base_i + imm_i.
  logic [1:0] byte_off;   // Low address bits selecting byte lane inside 32-bit word.
  logic [7:0] load_byte;  // Selected byte used by LB/LBU.
  logic [15:0] load_half; // Selected halfword used by LH/LHU.

  assign addr = base_i + imm_i;
  assign byte_off = addr[1:0];

  // Alignment rules follow RV32I natural alignment for halfword and word
  // accesses. Byte accesses are always aligned.
  always_comb begin
    unique case (size_i)
      CORE_LSU_HALF: misaligned_o = addr[0];
      CORE_LSU_WORD: misaligned_o = |addr[1:0];
      default:       misaligned_o = 1'b0;
    endcase
  end

  // Format the downstream memory request. Misaligned operations are converted
  // into a local fault and do not issue a request.
  always_comb begin
    req_valid_o = (load_i || store_i) && !misaligned_o;
    req_addr_o = addr;
    req_write_o = store_i;
    req_size_o = size_i;
    req_wdata_o = 32'h0000_0000;
    req_wstrb_o = 4'b0000;

    if (store_i && !misaligned_o) begin
      unique case (size_i)
        CORE_LSU_BYTE: begin
          unique case (byte_off)
            2'd0: begin
              req_wdata_o = {24'h000000, store_data_i[7:0]};
              req_wstrb_o = 4'b0001;
            end
            2'd1: begin
              req_wdata_o = {16'h0000, store_data_i[7:0], 8'h00};
              req_wstrb_o = 4'b0010;
            end
            2'd2: begin
              req_wdata_o = {8'h00, store_data_i[7:0], 16'h0000};
              req_wstrb_o = 4'b0100;
            end
            default: begin
              req_wdata_o = {store_data_i[7:0], 24'h000000};
              req_wstrb_o = 4'b1000;
            end
          endcase
        end
        CORE_LSU_HALF: begin
          if (addr[1]) begin
            req_wdata_o = {store_data_i[15:0], 16'h0000};
            req_wstrb_o = 4'b1100;
          end else begin
            req_wdata_o = {16'h0000, store_data_i[15:0]};
            req_wstrb_o = 4'b0011;
          end
        end
        default: begin
          req_wdata_o = store_data_i;
          req_wstrb_o = 4'b1111;
        end
      endcase
    end
  end

  // Extract and extend load response data according to address offset and load
  // signedness. The value is computed even for stores to keep the output stable.
  always_comb begin
    unique case (byte_off)
      2'd0: load_byte = rsp_rdata_i[7:0];
      2'd1: load_byte = rsp_rdata_i[15:8];
      2'd2: load_byte = rsp_rdata_i[23:16];
      default: load_byte = rsp_rdata_i[31:24];
    endcase

    load_half = addr[1] ? rsp_rdata_i[31:16] : rsp_rdata_i[15:0];

    unique case (size_i)
      CORE_LSU_BYTE: begin
        load_data_o = unsigned_i ? {24'h000000, load_byte} :
                                   {{24{load_byte[7]}}, load_byte};
      end
      CORE_LSU_HALF: begin
        load_data_o = unsigned_i ? {16'h0000, load_half} :
                                   {{16{load_half[15]}}, load_half};
      end
      default: begin
        load_data_o = rsp_rdata_i;
      end
    endcase
  end

  // A load/store fault is either detected locally or reported by memory.
  assign fault_o = misaligned_o || rsp_err_i;
endmodule
