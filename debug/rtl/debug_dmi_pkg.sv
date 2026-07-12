`timescale 1ns/1ps

// Shared RISC-V Debug Module Interface encodings used inside wasp1 debug RTL.
package debug_dmi_pkg;
  // The 7-bit address width covers every Debug Module register used by v0.13.x.
  localparam int DMI_ADDR_WIDTH = 7;

  // DMI request operations transported between the JTAG DTM and Debug Module.
  localparam logic [1:0] DMI_OP_NOP   = 2'b00;
  localparam logic [1:0] DMI_OP_READ  = 2'b01;
  localparam logic [1:0] DMI_OP_WRITE = 2'b10;

  // DMI response status encodings returned to the JTAG DTM.
  localparam logic [1:0] DMI_RESP_SUCCESS = 2'b00;
  localparam logic [1:0] DMI_RESP_FAILED  = 2'b10;
  localparam logic [1:0] DMI_RESP_BUSY    = 2'b11;

  // Stage-1 Debug Module register addresses from Debug Spec v0.13.x.
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_DATA0      = 7'h04;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_DATA1      = 7'h05;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_DMCONTROL  = 7'h10;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_DMSTATUS   = 7'h11;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_HARTINFO   = 7'h12;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_ABSTRACTCS = 7'h16;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_COMMAND    = 7'h17;
  // Canonical Program Buffer addresses are reserved now for the standalone
  // storage leaf; debug_dmi_regs does not route them until execution exists.
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_PROGBUF0   = 7'h20;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_PROGBUF1   = 7'h21;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_PROGBUF2   = 7'h22;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_PROGBUF3   = 7'h23;

  // Four words are enough for the first Program Buffer execution sequence
  // while keeping the register bank and future executor deliberately small.
  localparam int PROGBUF_WORD_COUNT = 4;
  // Explicit EBREAK terminates Program Buffer execution while impebreak is 0.
  localparam logic [31:0] PROGBUF_EBREAK_INSN = 32'h0010_0073;

  // Abstract command error encodings held in abstractcs.cmderr.
  localparam logic [2:0] CMDERR_NONE         = 3'd0;
  localparam logic [2:0] CMDERR_BUSY         = 3'd1;
  localparam logic [2:0] CMDERR_NOTSUP       = 3'd2;
  localparam logic [2:0] CMDERR_EXCEPTION    = 3'd3;
  localparam logic [2:0] CMDERR_HALT_RESUME  = 3'd4;
  localparam logic [2:0] CMDERR_BUS          = 3'd5;
  localparam logic [2:0] CMDERR_OTHER        = 3'd7;

  // Supported v0.13.x Access Register abstract-command encodings.
  localparam logic [7:0]  ABSTRACT_CMD_ACCESS_REGISTER = 8'h00;
  localparam logic [7:0]  ABSTRACT_CMD_ACCESS_MEMORY = 8'h02;
  localparam logic [2:0]  ABSTRACT_AARSIZE_32 = 3'd2;
  localparam logic [2:0]  ABSTRACT_AAMSIZE_8  = 3'd0;
  localparam logic [2:0]  ABSTRACT_AAMSIZE_16 = 3'd1;
  localparam logic [2:0]  ABSTRACT_AAMSIZE_32 = 3'd2;
  // Minimal read-only CSR values exposed for OpenOCD/GDB discovery.
  localparam logic [15:0] ABSTRACT_CSR_MSTATUS = 16'h0300;
  localparam logic [15:0] ABSTRACT_CSR_MISA = 16'h0301;
  localparam logic [15:0] ABSTRACT_CSR_TSELECT = 16'h07A0;
  localparam logic [15:0] ABSTRACT_CSR_TDATA1 = 16'h07A1;
  localparam logic [15:0] ABSTRACT_CSR_TDATA2 = 16'h07A2;
  localparam logic [15:0] ABSTRACT_CSR_TDATA3 = 16'h07A3;
  localparam logic [15:0] ABSTRACT_CSR_TINFO = 16'h07A4;
  localparam logic [15:0] ABSTRACT_CSR_TCONTROL = 16'h07A5;
  localparam logic [15:0] ABSTRACT_CSR_DCSR = 16'h07B0;
  localparam logic [15:0] ABSTRACT_CSR_DPC = 16'h07B1;
  localparam logic [31:0] ABSTRACT_CSR_MSTATUS_RV32_M = 32'h0000_0000;
  localparam logic [31:0] ABSTRACT_CSR_MISA_RV32I = 32'h4000_0100;
  localparam logic [31:0] ABSTRACT_CSR_DCSR_BASE_RV32_M = 32'h4000_0003;
  localparam logic [31:0] ABSTRACT_CSR_DCSR_HALTED_M = 32'h4000_00C3;
  localparam logic [31:0] ABSTRACT_CSR_DCSR_STEP_MASK = 32'h0000_0004;
  localparam logic [2:0]  ABSTRACT_DCSR_CAUSE_TRIGGER = 3'd2;
  localparam logic [2:0]  ABSTRACT_DCSR_CAUSE_HALTREQ = 3'd3;
  localparam logic [2:0]  ABSTRACT_DCSR_CAUSE_STEP = 3'd4;
  localparam logic [31:0] ABSTRACT_CSR_DPC_RESET = 32'h0000_0000;
  localparam logic [31:0] ABSTRACT_TINFO_MCONTROL_ONLY = 32'h0000_0004;
  // Stage-2 debug supports two execute-address mcontrol trigger slots so GDB
  // can keep more than one hardware breakpoint armed at the same time.
  localparam int ABSTRACT_TRIGGER_COUNT = 2;
  localparam logic [31:0] ABSTRACT_TDATA1_TYPE_MASK = 32'hF000_0000;
  localparam logic [31:0] ABSTRACT_TDATA1_TYPE_MCONTROL = 32'h2000_0000;
  localparam logic [31:0] ABSTRACT_TDATA1_DMODE = 32'h0800_0000;
  localparam logic [31:0] ABSTRACT_MCONTROL_ACTION_MASK = 32'h0000_F000;
  localparam logic [31:0] ABSTRACT_MCONTROL_ACTION_DEBUG = 32'h0000_1000;
  localparam logic [31:0] ABSTRACT_MCONTROL_MATCH_MASK = 32'h0000_0780;
  localparam logic [31:0] ABSTRACT_MCONTROL_M = 32'h0000_0040;
  localparam logic [31:0] ABSTRACT_MCONTROL_LOAD = 32'h0000_0001;
  localparam logic [31:0] ABSTRACT_MCONTROL_STORE = 32'h0000_0002;
  localparam logic [31:0] ABSTRACT_MCONTROL_EXECUTE = 32'h0000_0004;
  localparam logic [31:0] ABSTRACT_MCONTROL_LEGAL_MASK =
      ABSTRACT_TDATA1_TYPE_MASK | ABSTRACT_TDATA1_DMODE |
      ABSTRACT_MCONTROL_ACTION_MASK | ABSTRACT_MCONTROL_MATCH_MASK |
      ABSTRACT_MCONTROL_M | ABSTRACT_MCONTROL_EXECUTE |
      ABSTRACT_MCONTROL_LOAD | ABSTRACT_MCONTROL_STORE;
  localparam logic [15:0] ABSTRACT_GPR_BASE = 16'h1000;
  localparam logic [15:0] ABSTRACT_GPR_LAST = 16'h101F;
endpackage
