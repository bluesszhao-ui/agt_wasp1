`timescale 1ns/1ps

module core_csr (
  input  logic                         clk_i,
  input  logic                         rst_ni,

  input  logic                         csr_valid_i,
  input  core_types_pkg::core_csr_cmd_e csr_cmd_i,
  input  logic [11:0]                  csr_addr_i,
  input  logic [31:0]                  csr_wdata_i,
  output logic [31:0]                  csr_rdata_o,
  output logic                         csr_illegal_o,

  input  logic                         retire_i,

  input  logic                         trap_valid_i,
  input  logic                         trap_interrupt_i,
  input  logic [4:0]                   trap_cause_i,
  input  logic [31:0]                  trap_pc_i,
  input  logic [31:0]                  trap_tval_i,

  input  logic                         mret_i,

  input  logic                         timer_irq_i,
  input  logic                         external_irq_i,

  output logic [31:0]                  mtvec_o,
  output logic [31:0]                  mepc_o,
  output logic                         mie_global_o,
  output logic                         mtie_o,
  output logic                         meie_o,
  output logic                         mtip_o,
  output logic                         meip_o
);
  import core_types_pkg::*;
  import wasp1_pkg::*;

  localparam int MSTATUS_MIE_BIT  = 3;
  localparam int MSTATUS_MPIE_BIT = 7;
  localparam int MSTATUS_MPP_LSB  = 11;
  localparam int MIE_MTIE_BIT     = 7;
  localparam int MIE_MEIE_BIT     = 11;
  localparam int MIP_MTIP_BIT     = 7;
  localparam int MIP_MEIP_BIT     = 11;

  logic [31:0] mstatus_q;
  logic [31:0] mie_q;
  logic [31:0] mtvec_q;
  logic [31:0] mscratch_q;
  logic [31:0] mepc_q;
  logic [31:0] mcause_q;
  logic [31:0] mtval_q;
  logic [63:0] cycle_q;
  logic [63:0] instret_q;

  logic [31:0] mip_read;
  logic [31:0] csr_read_data;
  logic        csr_supported;
  logic        csr_read_only;
  logic [31:0] csr_write_data;
  logic        csr_write_en;

  assign mtvec_o = mtvec_q;
  assign mepc_o = mepc_q;
  assign mie_global_o = mstatus_q[MSTATUS_MIE_BIT];
  assign mtie_o = mie_q[MIE_MTIE_BIT];
  assign meie_o = mie_q[MIE_MEIE_BIT];
  assign mtip_o = timer_irq_i;
  assign meip_o = external_irq_i;

  always_comb begin
    mip_read = 32'h0000_0000;
    mip_read[MIP_MTIP_BIT] = timer_irq_i;
    mip_read[MIP_MEIP_BIT] = external_irq_i;
  end

  always_comb begin
    csr_supported = 1'b1;
    csr_read_only = 1'b0;
    unique case (csr_addr_i)
      CSR_MSTATUS:  csr_read_data = mstatus_q;
      CSR_MIE:      csr_read_data = mie_q;
      CSR_MTVEC:    csr_read_data = mtvec_q;
      CSR_MSCRATCH: csr_read_data = mscratch_q;
      CSR_MEPC:     csr_read_data = mepc_q;
      CSR_MCAUSE:   csr_read_data = mcause_q;
      CSR_MTVAL:    csr_read_data = mtval_q;
      CSR_MIP: begin
        csr_read_data = mip_read;
        csr_read_only = 1'b1;
      end
      CSR_CYCLE: begin
        csr_read_data = cycle_q[31:0];
        csr_read_only = 1'b1;
      end
      CSR_CYCLEH: begin
        csr_read_data = cycle_q[63:32];
        csr_read_only = 1'b1;
      end
      CSR_INSTRET: begin
        csr_read_data = instret_q[31:0];
        csr_read_only = 1'b1;
      end
      CSR_INSTRETH: begin
        csr_read_data = instret_q[63:32];
        csr_read_only = 1'b1;
      end
      default: begin
        csr_read_data = 32'h0000_0000;
        csr_supported = 1'b0;
        csr_read_only = 1'b0;
      end
    endcase
  end

  always_comb begin
    csr_write_data = csr_read_data;
    unique case (csr_cmd_i)
      CORE_CSR_RW,
      CORE_CSR_RWI: csr_write_data = csr_wdata_i;
      CORE_CSR_RS,
      CORE_CSR_RSI: csr_write_data = csr_read_data | csr_wdata_i;
      CORE_CSR_RC,
      CORE_CSR_RCI: csr_write_data = csr_read_data & ~csr_wdata_i;
      default:      csr_write_data = csr_read_data;
    endcase
  end

  assign csr_write_en = csr_valid_i && (csr_cmd_i != CORE_CSR_NONE) &&
                        csr_supported && !csr_read_only;
  assign csr_illegal_o = csr_valid_i &&
                         (!csr_supported ||
                          (csr_read_only && (csr_cmd_i != CORE_CSR_NONE)));
  assign csr_rdata_o = csr_read_data;

  function automatic logic [31:0] mask_mstatus(input logic [31:0] value);
    begin
      mask_mstatus = 32'h0000_0000;
      mask_mstatus[MSTATUS_MIE_BIT] = value[MSTATUS_MIE_BIT];
      mask_mstatus[MSTATUS_MPIE_BIT] = value[MSTATUS_MPIE_BIT];
      mask_mstatus[MSTATUS_MPP_LSB +: 2] = 2'b11;
    end
  endfunction

  function automatic logic [31:0] mask_mie(input logic [31:0] value);
    begin
      mask_mie = 32'h0000_0000;
      mask_mie[MIE_MTIE_BIT] = value[MIE_MTIE_BIT];
      mask_mie[MIE_MEIE_BIT] = value[MIE_MEIE_BIT];
    end
  endfunction

  function automatic logic [31:0] mask_mtvec(input logic [31:0] value);
    begin
      mask_mtvec = {value[31:2], 2'b00};
    end
  endfunction

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mstatus_q <= 32'h0000_1800;
      mie_q <= 32'h0000_0000;
      mtvec_q <= 32'h0000_0000;
      mscratch_q <= 32'h0000_0000;
      mepc_q <= 32'h0000_0000;
      mcause_q <= 32'h0000_0000;
      mtval_q <= 32'h0000_0000;
      cycle_q <= 64'h0000_0000_0000_0000;
      instret_q <= 64'h0000_0000_0000_0000;
    end else begin
      cycle_q <= cycle_q + 64'd1;
      if (retire_i) begin
        instret_q <= instret_q + 64'd1;
      end

      if (csr_write_en) begin
        unique case (csr_addr_i)
          CSR_MSTATUS:  mstatus_q <= mask_mstatus(csr_write_data);
          CSR_MIE:      mie_q <= mask_mie(csr_write_data);
          CSR_MTVEC:    mtvec_q <= mask_mtvec(csr_write_data);
          CSR_MSCRATCH: mscratch_q <= csr_write_data;
          CSR_MEPC:     mepc_q <= {csr_write_data[31:1], 1'b0};
          CSR_MCAUSE:   mcause_q <= csr_write_data;
          CSR_MTVAL:    mtval_q <= csr_write_data;
          default: begin
          end
        endcase
      end

      if (trap_valid_i) begin
        mstatus_q[MSTATUS_MPIE_BIT] <= mstatus_q[MSTATUS_MIE_BIT];
        mstatus_q[MSTATUS_MIE_BIT] <= 1'b0;
        mstatus_q[MSTATUS_MPP_LSB +: 2] <= 2'b11;
        mepc_q <= {trap_pc_i[31:1], 1'b0};
        mcause_q <= {trap_interrupt_i, 26'h000_0000, trap_cause_i};
        mtval_q <= trap_tval_i;
      end else if (mret_i) begin
        mstatus_q[MSTATUS_MIE_BIT] <= mstatus_q[MSTATUS_MPIE_BIT];
        mstatus_q[MSTATUS_MPIE_BIT] <= 1'b1;
        mstatus_q[MSTATUS_MPP_LSB +: 2] <= 2'b11;
      end
    end
  end
endmodule
