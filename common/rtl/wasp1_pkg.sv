`timescale 1ns/1ps

package wasp1_pkg;
  localparam int XLEN       = 32;
  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  localparam int STRB_WIDTH = DATA_WIDTH / 8;

  localparam logic [31:0] OTP_BASE     = 32'h0000_0000;
  localparam logic [31:0] ISRAM_BASE   = 32'h1000_0000;
  localparam logic [31:0] DSRAM_BASE   = 32'h2000_0000;
  localparam logic [31:0] DMA_BASE     = 32'h4000_0000;
  localparam logic [31:0] WDG_BASE     = 32'h4001_0000;
  localparam logic [31:0] TIMER_BASE   = 32'h4002_0000;
  localparam logic [31:0] INTC_BASE    = 32'h4003_0000;
  localparam logic [31:0] UART_BASE    = 32'h4004_0000;
  localparam logic [31:0] I2C_BASE     = 32'h4005_0000;
  localparam logic [31:0] GPIO_BASE    = 32'h4006_0000;

  localparam logic [31:0] OTP_SIZE     = 32'h0001_0000;
  localparam logic [31:0] ISRAM_SIZE   = 32'h0001_0000;
  localparam logic [31:0] DSRAM_SIZE   = 32'h0001_0000;
  localparam logic [31:0] PERIPH_SIZE  = 32'h0000_1000;

  localparam int AHB_SLAVE_OTP     = 0;
  localparam int AHB_SLAVE_ISRAM   = 1;
  localparam int AHB_SLAVE_DSRAM   = 2;
  localparam int AHB_SLAVE_DMA     = 3;
  localparam int AHB_SLAVE_WDG     = 4;
  localparam int AHB_SLAVE_TIMER   = 5;
  localparam int AHB_SLAVE_INTC    = 6;
  localparam int AHB_SLAVE_UART    = 7;
  localparam int AHB_SLAVE_I2C     = 8;
  localparam int AHB_SLAVE_GPIO    = 9;
  localparam int AHB_SLAVE_DEFAULT = 10;
  localparam int AHB_SLAVE_COUNT   = 11;

  localparam logic [31:0] OTP_REG_WINDOW_SIZE = 32'h0000_0100;
  localparam logic [31:0] OTP_DATA_SIZE = OTP_SIZE - OTP_REG_WINDOW_SIZE;
  localparam logic [31:0] OTP_REG_BASE = OTP_BASE + OTP_DATA_SIZE;
  localparam logic [31:0] OTP_CTRL_OFFSET   = 32'h0000_0000;
  localparam logic [31:0] OTP_STATUS_OFFSET = 32'h0000_0004;
  localparam logic [31:0] OTP_ADDR_OFFSET   = 32'h0000_0008;
  localparam logic [31:0] OTP_WDATA_OFFSET  = 32'h0000_000C;
  localparam logic [31:0] OTP_RDATA_OFFSET  = 32'h0000_0010;
  localparam logic [31:0] OTP_KEY_OFFSET    = 32'h0000_0014;
  localparam logic [31:0] OTP_LOCK_OFFSET   = 32'h0000_0018;
  localparam logic [31:0] OTP_KEY_VALUE     = 32'h5750_4F54;
  localparam int OTP_CTRL_PROG_EN_BIT = 0;
  localparam int OTP_CTRL_START_BIT   = 1;
  localparam int OTP_CTRL_CLEAR_BIT   = 2;
  localparam int OTP_STATUS_BUSY_BIT  = 0;
  localparam int OTP_STATUS_DONE_BIT  = 1;
  localparam int OTP_STATUS_ERROR_BIT = 2;
  localparam int OTP_STATUS_LOCK_BIT  = 3;

  localparam logic [31:0] TIMER_CTRL_OFFSET      = 32'h0000_0000;
  localparam logic [31:0] TIMER_STATUS_OFFSET    = 32'h0000_0004;
  localparam logic [31:0] TIMER_MTIME_LO_OFFSET  = 32'h0000_0008;
  localparam logic [31:0] TIMER_MTIME_HI_OFFSET  = 32'h0000_000C;
  localparam logic [31:0] TIMER_CMP_LO_OFFSET    = 32'h0000_0010;
  localparam logic [31:0] TIMER_CMP_HI_OFFSET    = 32'h0000_0014;
  localparam int TIMER_CTRL_ENABLE_BIT = 0;
  localparam int TIMER_CTRL_IRQ_EN_BIT = 1;
  localparam int TIMER_STATUS_PENDING_BIT = 0;

  localparam logic [31:0] GPIO_DATA_IN_OFFSET    = 32'h0000_0000;
  localparam logic [31:0] GPIO_DATA_OUT_OFFSET   = 32'h0000_0004;
  localparam logic [31:0] GPIO_DIR_OFFSET        = 32'h0000_0008;
  localparam logic [31:0] GPIO_SET_OFFSET        = 32'h0000_000C;
  localparam logic [31:0] GPIO_CLR_OFFSET        = 32'h0000_0010;
  localparam logic [31:0] GPIO_TOGGLE_OFFSET     = 32'h0000_0014;
  localparam logic [31:0] GPIO_IRQ_EN_OFFSET     = 32'h0000_0018;
  localparam logic [31:0] GPIO_IRQ_TYPE_OFFSET   = 32'h0000_001C;
  localparam logic [31:0] GPIO_IRQ_POL_OFFSET    = 32'h0000_0020;
  localparam logic [31:0] GPIO_IRQ_STATUS_OFFSET = 32'h0000_0024;

  localparam int CACHE_LINE_BYTES = 16;
  localparam int CACHE_LINE_BITS  = CACHE_LINE_BYTES * 8;

  typedef enum logic [1:0] {
    AHB_HTRANS_IDLE   = 2'b00,
    AHB_HTRANS_BUSY   = 2'b01,
    AHB_HTRANS_NONSEQ = 2'b10,
    AHB_HTRANS_SEQ    = 2'b11
  } ahb_htrans_e;

  typedef enum logic [2:0] {
    AHB_HSIZE_BYTE  = 3'b000,
    AHB_HSIZE_HALF  = 3'b001,
    AHB_HSIZE_WORD  = 3'b010
  } ahb_hsize_e;

  typedef enum logic [2:0] {
    AHB_HBURST_SINGLE = 3'b000
  } ahb_hburst_e;

  typedef enum logic {
    AHB_HRESP_OKAY  = 1'b0,
    AHB_HRESP_ERROR = 1'b1
  } ahb_hresp_e;

  typedef enum logic [1:0] {
    MEM_SIZE_BYTE = 2'b00,
    MEM_SIZE_HALF = 2'b01,
    MEM_SIZE_WORD = 2'b10
  } mem_size_e;

  typedef enum logic [3:0] {
    IRQ_ID_NONE  = 4'd0,
    IRQ_ID_WDG   = 4'd1,
    IRQ_ID_UART  = 4'd2,
    IRQ_ID_I2C   = 4'd3,
    IRQ_ID_GPIO  = 4'd4,
    IRQ_ID_DMA   = 4'd5
  } irq_id_e;

  localparam int IRQ_SRC_COUNT = 6;

  localparam logic [11:0] CSR_MSTATUS  = 12'h300;
  localparam logic [11:0] CSR_MIE      = 12'h304;
  localparam logic [11:0] CSR_MTVEC    = 12'h305;
  localparam logic [11:0] CSR_MSCRATCH = 12'h340;
  localparam logic [11:0] CSR_MEPC     = 12'h341;
  localparam logic [11:0] CSR_MCAUSE   = 12'h342;
  localparam logic [11:0] CSR_MTVAL    = 12'h343;
  localparam logic [11:0] CSR_MIP      = 12'h344;
  localparam logic [11:0] CSR_CYCLE    = 12'hC00;
  localparam logic [11:0] CSR_INSTRET  = 12'hC02;
  localparam logic [11:0] CSR_CYCLEH   = 12'hC80;
  localparam logic [11:0] CSR_INSTRETH = 12'hC82;

  localparam logic [4:0] TRAP_CAUSE_IADDR_MISALIGNED = 5'd0;
  localparam logic [4:0] TRAP_CAUSE_ILLEGAL_INSN     = 5'd2;
  localparam logic [4:0] TRAP_CAUSE_BREAKPOINT       = 5'd3;
  localparam logic [4:0] TRAP_CAUSE_LOAD_MISALIGNED  = 5'd4;
  localparam logic [4:0] TRAP_CAUSE_STORE_MISALIGNED = 5'd6;
  localparam logic [4:0] TRAP_CAUSE_M_TIMER_IRQ      = 5'd7;
  localparam logic [4:0] TRAP_CAUSE_ECALL_MMODE      = 5'd11;
  localparam logic [4:0] TRAP_CAUSE_M_EXTERNAL_IRQ   = 5'd11;
endpackage
