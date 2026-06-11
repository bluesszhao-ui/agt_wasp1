`timescale 1ns/1ps

module core_lsu (
  input  logic [31:0]                  base_i,
  input  logic [31:0]                  imm_i,
  input  logic [31:0]                  store_data_i,
  input  core_types_pkg::core_lsu_size_e size_i,
  input  logic                         unsigned_i,
  input  logic                         load_i,
  input  logic                         store_i,
  input  logic [31:0]                  rsp_rdata_i,
  input  logic                         rsp_err_i,

  output logic                         req_valid_o,
  output logic [31:0]                  req_addr_o,
  output logic                         req_write_o,
  output logic [1:0]                   req_size_o,
  output logic [31:0]                  req_wdata_o,
  output logic [3:0]                   req_wstrb_o,

  output logic [31:0]                  load_data_o,
  output logic                         misaligned_o,
  output logic                         fault_o
);
  import core_types_pkg::*;

  logic [31:0] addr;
  logic [1:0] byte_off;
  logic [7:0] load_byte;
  logic [15:0] load_half;

  assign addr = base_i + imm_i;
  assign byte_off = addr[1:0];

  always_comb begin
    unique case (size_i)
      CORE_LSU_HALF: misaligned_o = addr[0];
      CORE_LSU_WORD: misaligned_o = |addr[1:0];
      default:       misaligned_o = 1'b0;
    endcase
  end

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

  assign fault_o = misaligned_o || rsp_err_i;
endmodule
