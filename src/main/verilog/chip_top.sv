// See LICENSE for license details.

import dii_package::dii_flit;

`include "consts.vh"
`include "dev_map.vh"
`include "config.vh"

module chip_top
  (
`ifdef ADD_PHY_DDR
 `ifdef KC705
   // DDR3 RAM
   inout [63:0]  ddr_dq,
   inout [7:0]   ddr_dqs_n,
   inout [7:0]   ddr_dqs_p,
   output [13:0] ddr_addr,
   output [2:0]  ddr_ba,
   output        ddr_ras_n,
   output        ddr_cas_n,
   output        ddr_we_n,
   output        ddr_reset_n,
   output        ddr_ck_n,
   output        ddr_ck_p,
   output        ddr_cke,
   output        ddr_cs_n,
   output [7:0]  ddr_dm,
   output        ddr_odt,
 `elsif NEXYS4_VIDEO
   // DDR3 RAM
     inout [15:0]  ddr_dq,
     inout [1:0]   ddr_dqs_n,
     inout [1:0]   ddr_dqs_p,
     output [14:0] ddr_addr,
     output [2:0]  ddr_ba,
     output        ddr_ras_n,
     output        ddr_cas_n,
     output        ddr_we_n,
     output        ddr_reset_n,
     output        ddr_ck_n,
     output        ddr_ck_p,
     output        ddr_cke,
 //    output        ddr_cs_n,
     output [1:0]  ddr_dm,
     output        ddr_odt,
 `elsif NEXYS4
   // DDR2 RAM
   inout [15:0]  ddr_dq,
   inout [1:0]   ddr_dqs_n,
   inout [1:0]   ddr_dqs_p,
   output [12:0] ddr_addr,
   output [2:0]  ddr_ba,
   output        ddr_ras_n,
   output        ddr_cas_n,
   output        ddr_we_n,
   output        ddr_ck_n,
   output        ddr_ck_p,
   output        ddr_cke,
   output        ddr_cs_n,
   output [1:0]  ddr_dm,
   output        ddr_odt,
 `endif
`endif //  `ifdef ADD_DDR_IO

`ifdef ADD_UART_IO
   input         rxd,
   output        txd,
`endif

`ifdef ADD_SPI
   inout         spi_cs,
   inout         spi_sclk,
   inout         spi_mosi,
   inout         spi_miso,
`endif

   // clock and reset
   input         clk_p,
   input         clk_n,
   input         rst_top
   );

   // internal clock and reset signals
   logic  clk, rst, rstn;
   assign rst = !rstn;

   // Debug controlled reset of the Rocket system
   logic  sys_rst, cpu_rst;

   // interrupt line
   logic [63:0]                interrupt;

   /////////////////////////////////////////////////////////////
   // NASTI/Lite on-chip interconnects

   // Rocket memory nasti bus
   nasti_channel
     #(
       .ID_WIDTH    ( `ROCKET_MEM_TAG_WIDTH ),
       .ADDR_WIDTH  ( `ROCKET_PADDR_WIDTH   ),
       .DATA_WIDTH  ( `ROCKET_MEM_DAT_WIDTH ))
   mem_nasti();

   // Rocket IO nasti-lite bus
   nasti_channel
     #(
       .ID_WIDTH    ( 1              ),
       .ADDR_WIDTH  ( `ROCKET_PADDR_WIDTH   ),
       .DATA_WIDTH  ( `ROCKET_IO_DAT_WIDTH  ))
   io_nasti();

   nasti_channel
     #(
       .ID_WIDTH    ( 1              ),
       .ADDR_WIDTH  ( `ROCKET_PADDR_WIDTH   ),
       .DATA_WIDTH  ( `LOWRISC_IO_DAT_WIDTH ))
   io_lite();

   /////////////////////////////////////////////////////////////
   // Memory System

`ifdef ADD_PHY_DDR

   // the NASTI bus for off-FPGA DRAM, converted to High frequency
   nasti_channel   
     #(
       .ID_WIDTH    ( `ROCKET_MEM_TAG_WIDTH ),
       .ADDR_WIDTH  ( `ROCKET_PADDR_WIDTH   ),
       .DATA_WIDTH  ( `ROCKET_MEM_DAT_WIDTH ))
   mem_mig_nasti();

   // MIG clock
   logic mig_ui_clk, mig_ui_rst, mig_ui_rstn;
   assign mig_ui_rstn = !mig_ui_rst;

   // clock converter
   axi_clock_converter_0 clk_conv
     (
      .s_axi_aclk           ( clk                      ),
      .s_axi_aresetn        ( rstn                     ),
      .s_axi_awid           ( mem_nasti.aw_id          ),
      .s_axi_awaddr         ( mem_nasti.aw_addr        ),
      .s_axi_awlen          ( mem_nasti.aw_len         ),
      .s_axi_awsize         ( mem_nasti.aw_size        ),
      .s_axi_awburst        ( mem_nasti.aw_burst       ),
      .s_axi_awlock         ( 1'b0                     ), // not supported in AXI4
      .s_axi_awcache        ( mem_nasti.aw_cache       ),
      .s_axi_awprot         ( mem_nasti.aw_prot        ),
      .s_axi_awqos          ( mem_nasti.aw_qos         ),
      .s_axi_awregion       ( mem_nasti.aw_region      ),
      .s_axi_awvalid        ( mem_nasti.aw_valid       ),
      .s_axi_awready        ( mem_nasti.aw_ready       ),
      .s_axi_wdata          ( mem_nasti.w_data         ),
      .s_axi_wstrb          ( mem_nasti.w_strb         ),
      .s_axi_wlast          ( mem_nasti.w_last         ),
      .s_axi_wvalid         ( mem_nasti.w_valid        ),
      .s_axi_wready         ( mem_nasti.w_ready        ),
      .s_axi_bid            ( mem_nasti.b_id           ),
      .s_axi_bresp          ( mem_nasti.b_resp         ),
      .s_axi_bvalid         ( mem_nasti.b_valid        ),
      .s_axi_bready         ( mem_nasti.b_ready        ),
      .s_axi_arid           ( mem_nasti.ar_id          ),
      .s_axi_araddr         ( mem_nasti.ar_addr        ),
      .s_axi_arlen          ( mem_nasti.ar_len         ),
      .s_axi_arsize         ( mem_nasti.ar_size        ),
      .s_axi_arburst        ( mem_nasti.ar_burst       ),
      .s_axi_arlock         ( 1'b0                     ), // not supported in AXI4
      .s_axi_arcache        ( mem_nasti.ar_cache       ),
      .s_axi_arprot         ( mem_nasti.ar_prot        ),
      .s_axi_arqos          ( mem_nasti.ar_qos         ),
      .s_axi_arregion       ( mem_nasti.ar_region      ),
      .s_axi_arvalid        ( mem_nasti.ar_valid       ),
      .s_axi_arready        ( mem_nasti.ar_ready       ),
      .s_axi_rid            ( mem_nasti.r_id           ),
      .s_axi_rdata          ( mem_nasti.r_data         ),
      .s_axi_rresp          ( mem_nasti.r_resp         ),
      .s_axi_rlast          ( mem_nasti.r_last         ),
      .s_axi_rvalid         ( mem_nasti.r_valid        ),
      .s_axi_rready         ( mem_nasti.r_ready        ),
      .m_axi_aclk           ( mig_ui_clk               ),
      .m_axi_aresetn        ( mig_ui_rstn              ),
      .m_axi_awid           ( mem_mig_nasti.aw_id      ),
      .m_axi_awaddr         ( mem_mig_nasti.aw_addr    ),
      .m_axi_awlen          ( mem_mig_nasti.aw_len     ),
      .m_axi_awsize         ( mem_mig_nasti.aw_size    ),
      .m_axi_awburst        ( mem_mig_nasti.aw_burst   ),
      .m_axi_awlock         (                          ), // not supported in AXI4
      .m_axi_awcache        ( mem_mig_nasti.aw_cache   ),
      .m_axi_awprot         ( mem_mig_nasti.aw_prot    ),
      .m_axi_awqos          ( mem_mig_nasti.aw_qos     ),
      .m_axi_awregion       ( mem_mig_nasti.aw_region  ),
      .m_axi_awvalid        ( mem_mig_nasti.aw_valid   ),
      .m_axi_awready        ( mem_mig_nasti.aw_ready   ),
      .m_axi_wdata          ( mem_mig_nasti.w_data     ),
      .m_axi_wstrb          ( mem_mig_nasti.w_strb     ),
      .m_axi_wlast          ( mem_mig_nasti.w_last     ),
      .m_axi_wvalid         ( mem_mig_nasti.w_valid    ),
      .m_axi_wready         ( mem_mig_nasti.w_ready    ),
      .m_axi_bid            ( mem_mig_nasti.b_id       ),
      .m_axi_bresp          ( mem_mig_nasti.b_resp     ),
      .m_axi_bvalid         ( mem_mig_nasti.b_valid    ),
      .m_axi_bready         ( mem_mig_nasti.b_ready    ),
      .m_axi_arid           ( mem_mig_nasti.ar_id      ),
      .m_axi_araddr         ( mem_mig_nasti.ar_addr    ),
      .m_axi_arlen          ( mem_mig_nasti.ar_len     ),
      .m_axi_arsize         ( mem_mig_nasti.ar_size    ),
      .m_axi_arburst        ( mem_mig_nasti.ar_burst   ),
      .m_axi_arlock         (                          ), // not supported in AXI4
      .m_axi_arcache        ( mem_mig_nasti.ar_cache   ),
      .m_axi_arprot         ( mem_mig_nasti.ar_prot    ),
      .m_axi_arqos          ( mem_mig_nasti.ar_qos     ),
      .m_axi_arregion       ( mem_mig_nasti.ar_region  ),
      .m_axi_arvalid        ( mem_mig_nasti.ar_valid   ),
      .m_axi_arready        ( mem_mig_nasti.ar_ready   ),
      .m_axi_rid            ( mem_mig_nasti.r_id       ),
      .m_axi_rdata          ( mem_mig_nasti.r_data     ),
      .m_axi_rresp          ( mem_mig_nasti.r_resp     ),
      .m_axi_rlast          ( mem_mig_nasti.r_last     ),
      .m_axi_rvalid         ( mem_mig_nasti.r_valid    ),
      .m_axi_rready         ( mem_mig_nasti.r_ready    )
      );

 `ifdef NEXYS4_VIDEO
        //clock generator
        logic mig_sys_clk, clk_locked;
        clk_wiz_0 clk_gen
          (
           .clk_in1     ( clk_p         ), // 100 MHz onboard
           .clk_out1    ( mig_sys_clk   ), // 200 MHz
           .reset       ( rst_top       ),
           .locked      ( clk_locked    )
           );
 `endif //  `ifdef NEXYS4

 `ifdef NEXYS4
        //clock generator
        logic mig_sys_clk, clk_locked;
        clk_wiz_0 clk_gen
          (
           .clk_in1     ( clk_p         ), // 100 MHz onboard
           .clk_out1    ( mig_sys_clk   ), // 200 MHz
           .resetn      ( rst_top       ),
           .locked      ( clk_locked    )
           );
 `endif //  `ifdef NEXYS4

   // DRAM controller
   mig_7series_0 dram_ctl
     (
 `ifdef KC705
      .sys_clk_p            ( clk_p                  ),
      .sys_clk_n            ( clk_n                  ),
      .sys_rst              ( rst_top                ),
      .ui_addn_clk_0        ( clk                    ),
      .ddr3_dq              ( ddr_dq                 ),
      .ddr3_dqs_n           ( ddr_dqs_n              ),
      .ddr3_dqs_p           ( ddr_dqs_p              ),
      .ddr3_addr            ( ddr_addr               ),
      .ddr3_ba              ( ddr_ba                 ),
      .ddr3_ras_n           ( ddr_ras_n              ),
      .ddr3_cas_n           ( ddr_cas_n              ),
      .ddr3_we_n            ( ddr_we_n               ),
      .ddr3_reset_n         ( ddr_reset_n            ),
      .ddr3_ck_p            ( ddr_ck_p               ),
      .ddr3_ck_n            ( ddr_ck_n               ),
      .ddr3_cke             ( ddr_cke                ),
      .ddr3_cs_n            ( ddr_cs_n               ),
      .ddr3_dm              ( ddr_dm                 ),
      .ddr3_odt             ( ddr_odt                ),
 `elsif NEXYS4_VIDEO
     // System Clock Ports
     .sys_clk_i                      (mig_sys_clk),
     .sys_rst                        (clk_locked), // input sys_rst
     .ui_addn_clk_0                  (clk),
     .device_temp_i                  (0),
     // Memory interface ports
     .ddr3_addr                      (ddr_addr),  // output [14:0]        ddr3_addr
     .ddr3_ba                        (ddr_ba),  // output [2:0]        ddr3_ba
     .ddr3_cas_n                     (ddr_cas_n),  // output            ddr3_cas_n
     .ddr3_ck_n                      (ddr_ck_n),  // output [0:0]        ddr3_ck_n
     .ddr3_ck_p                      (ddr_ck_p),  // output [0:0]        ddr3_ck_p
     .ddr3_cke                       (ddr_cke),  // output [0:0]        ddr3_cke
     .ddr3_ras_n                     (ddr_ras_n),  // output            ddr3_ras_n
     .ddr3_reset_n                   (ddr_reset_n),  // output            ddr3_reset_n
     .ddr3_we_n                      (ddr_we_n),  // output            ddr3_we_n
     .ddr3_dq                        (ddr_dq),  // inout [15:0]        ddr3_dq
     .ddr3_dqs_n                     (ddr_dqs_n),  // inout [1:0]        ddr3_dqs_n
     .ddr3_dqs_p                     (ddr_dqs_p),  // inout [1:0]        ddr3_dqs_p
     .init_calib_complete            (init_calib_complete),  // output            init_calib_complete
       
     .ddr3_dm                        (ddr_dm),  // output [1:0]        ddr3_dm
     .ddr3_odt                       (ddr_odt),  // output [0:0]        ddr3_odt
 `elsif NEXYS4
      .sys_clk_i            ( mig_sys_clk            ),
      .sys_rst              ( clk_locked             ),
      .ui_addn_clk_0        ( clk                    ),
      .device_temp_i        ( 0                      ),
      .ddr2_dq              ( ddr_dq                 ),
      .ddr2_dqs_n           ( ddr_dqs_n              ),
      .ddr2_dqs_p           ( ddr_dqs_p              ),
      .ddr2_addr            ( ddr_addr               ),
      .ddr2_ba              ( ddr_ba                 ),
      .ddr2_ras_n           ( ddr_ras_n              ),
      .ddr2_cas_n           ( ddr_cas_n              ),
      .ddr2_we_n            ( ddr_we_n               ),
      .ddr2_ck_p            ( ddr_ck_p               ),
      .ddr2_ck_n            ( ddr_ck_n               ),
      .ddr2_cke             ( ddr_cke                ),
      .ddr2_cs_n            ( ddr_cs_n               ),
      .ddr2_dm              ( ddr_dm                 ),
      .ddr2_odt             ( ddr_odt                ),
 `endif // !`elsif NEXYS4
      .ui_clk               ( mig_ui_clk             ),
      .ui_clk_sync_rst      ( mig_ui_rst             ),
      .mmcm_locked          ( rstn                   ),
      .aresetn              ( rstn                   ), // AXI reset
      .app_sr_req           ( 1'b0                   ),
      .app_ref_req          ( 1'b0                   ),
      .app_zq_req           ( 1'b0                   ),
      .s_axi_awid           ( mem_mig_nasti.aw_id    ),
      .s_axi_awaddr         ( mem_mig_nasti.aw_addr  ),
      .s_axi_awlen          ( mem_mig_nasti.aw_len   ),
      .s_axi_awsize         ( mem_mig_nasti.aw_size  ),
      .s_axi_awburst        ( mem_mig_nasti.aw_burst ),
      .s_axi_awlock         ( 1'b0                   ), // not supported in AXI4
      .s_axi_awcache        ( mem_mig_nasti.aw_cache ),
      .s_axi_awprot         ( mem_mig_nasti.aw_prot  ),
      .s_axi_awqos          ( mem_mig_nasti.aw_qos   ),
      .s_axi_awvalid        ( mem_mig_nasti.aw_valid ),
      .s_axi_awready        ( mem_mig_nasti.aw_ready ),
      .s_axi_wdata          ( mem_mig_nasti.w_data   ),
      .s_axi_wstrb          ( mem_mig_nasti.w_strb   ),
      .s_axi_wlast          ( mem_mig_nasti.w_last   ),
      .s_axi_wvalid         ( mem_mig_nasti.w_valid  ),
      .s_axi_wready         ( mem_mig_nasti.w_ready  ),
      .s_axi_bid            ( mem_mig_nasti.b_id     ),
      .s_axi_bresp          ( mem_mig_nasti.b_resp   ),
      .s_axi_bvalid         ( mem_mig_nasti.b_valid  ),
      .s_axi_bready         ( mem_mig_nasti.b_ready  ),
      .s_axi_arid           ( mem_mig_nasti.ar_id    ),
      .s_axi_araddr         ( mem_mig_nasti.ar_addr  ),
      .s_axi_arlen          ( mem_mig_nasti.ar_len   ),
      .s_axi_arsize         ( mem_mig_nasti.ar_size  ),
      .s_axi_arburst        ( mem_mig_nasti.ar_burst ),
      .s_axi_arlock         ( 1'b0                   ), // not supported in AXI4
      .s_axi_arcache        ( mem_mig_nasti.ar_cache ),
      .s_axi_arprot         ( mem_mig_nasti.ar_prot  ),
      .s_axi_arqos          ( mem_mig_nasti.ar_qos   ),
      .s_axi_arvalid        ( mem_mig_nasti.ar_valid ),
      .s_axi_arready        ( mem_mig_nasti.ar_ready ),
      .s_axi_rid            ( mem_mig_nasti.r_id     ),
      .s_axi_rdata          ( mem_mig_nasti.r_data   ),
      .s_axi_rresp          ( mem_mig_nasti.r_resp   ),
      .s_axi_rlast          ( mem_mig_nasti.r_last   ),
      .s_axi_rvalid         ( mem_mig_nasti.r_valid  ),
      .s_axi_rready         ( mem_mig_nasti.r_ready  )
      );

`else

   assign clk = clk_p;
   assign rstn = !rst_top;

   nasti_ram_behav
     #(
       .ID_WIDTH     ( `ROCKET_MEM_TAG_WIDTH   ),
       .ADDR_WIDTH   ( `ROCKET_PADDR_WIDTH     ),
       .DATA_WIDTH   ( `ROCKET_MEM_DAT_WIDTH   ),
       .USER_WIDTH   ( 1                )
       )
   ram_behav
     (
      .clk           ( clk         ),
      .rstn          ( rstn        ),
      .nasti         ( mem_nasti   )
      );
`endif // !`ifdef ADD_PHY_DDR

   /////////////////////////////////////////////////////////////
   // On-chip Block RAM

   nasti_channel
     #(
       .ADDR_WIDTH  ( `ROCKET_PADDR_WIDTH       ),
       .DATA_WIDTH  ( `LOWRISC_IO_DAT_WIDTH     ))
   io_bram_lite();

`ifdef ADD_BRAM
   localparam BRAM_SIZE          = 16;        // 2^16 -> 64 KB
   localparam BRAM_WIDTH         = 128;       // always 128-bit wide
   localparam BRAM_LINE          = 2 ** BRAM_SIZE / (BRAM_WIDTH/8);
   localparam BRAM_OFFSET_BITS   = $clog2(`LOWRISC_IO_DAT_WIDTH/8);
   localparam BRAM_ADDR_LSB_BITS = $clog2(BRAM_WIDTH / `LOWRISC_IO_DAT_WIDTH);
   localparam BRAM_ADDR_BLK_BITS = BRAM_SIZE - BRAM_ADDR_LSB_BITS - BRAM_OFFSET_BITS;

   initial assert (BRAM_OFFSET_BITS < 7) else $fatal(1, "Do not support BRAM AXI width > 64-bit!");

   // BRAM controller
   logic ram_clk, ram_rst, ram_en;
   logic [`LOWRISC_IO_DAT_WIDTH/8-1:0] ram_we;
   logic [BRAM_SIZE-1:0]               ram_addr;
   logic [`LOWRISC_IO_DAT_WIDTH-1:0]   ram_wrdata, ram_rddata;

   axi_bram_ctrl_0 BramCtl
     (
      .s_axi_aclk      ( clk                     ),
      .s_axi_aresetn   ( rstn                    ),
      .s_axi_araddr    ( io_bram_lite.ar_addr    ),
      .s_axi_arprot    ( 3'b000                  ),
      .s_axi_arready   ( io_bram_lite.ar_ready   ),
      .s_axi_arvalid   ( io_bram_lite.ar_valid   ),
      .s_axi_awaddr    ( io_bram_lite.aw_addr    ),
      .s_axi_awprot    ( 3'b000                  ),
      .s_axi_awready   ( io_bram_lite.aw_ready   ),
      .s_axi_awvalid   ( io_bram_lite.aw_valid   ),
      .s_axi_bready    ( io_bram_lite.b_ready    ),
      .s_axi_bresp     ( io_bram_lite.b_resp     ),
      .s_axi_bvalid    ( io_bram_lite.b_valid    ),
      .s_axi_rdata     ( io_bram_lite.r_data     ),
      .s_axi_rready    ( io_bram_lite.r_ready    ),
      .s_axi_rresp     ( io_bram_lite.r_resp     ),
      .s_axi_rvalid    ( io_bram_lite.r_valid    ),
      .s_axi_wdata     ( io_bram_lite.w_data     ),
      .s_axi_wready    ( io_bram_lite.w_ready    ),
      .s_axi_wstrb     ( io_bram_lite.w_strb     ),
      .s_axi_wvalid    ( io_bram_lite.w_valid    ),
      .bram_rst_a      ( ram_rst                 ),
      .bram_clk_a      ( ram_clk                 ),
      .bram_en_a       ( ram_en                  ),
      .bram_we_a       ( ram_we                  ),
      .bram_addr_a     ( ram_addr                ),
      .bram_wrdata_a   ( ram_wrdata              ),
      .bram_rddata_a   ( ram_rddata              )
      );

   // the inferred BRAMs
   reg   [BRAM_WIDTH-1:0]         ram [0 : BRAM_LINE-1];
   logic [BRAM_ADDR_BLK_BITS-1:0] ram_block_addr, ram_block_addr_delay;
   logic [BRAM_ADDR_LSB_BITS-1:0] ram_lsb_addr, ram_lsb_addr_delay;
   logic [BRAM_WIDTH/8-1:0]       ram_we_full;
   logic [BRAM_WIDTH-1:0]         ram_wrdata_full, ram_rddata_full;
   int                            ram_rddata_shift, ram_we_shift, i;

   assign ram_block_addr = ram_addr >> BRAM_ADDR_LSB_BITS + BRAM_OFFSET_BITS;
   assign ram_lsb_addr = ram_addr >> BRAM_OFFSET_BITS;
   assign ram_we_shift = ram_lsb_addr << BRAM_OFFSET_BITS; // avoid ISim error
   assign ram_we_full = ram_we << ram_we_shift;
   assign ram_wrdata_full = {(BRAM_WIDTH / `LOWRISC_IO_DAT_WIDTH){ram_wrdata}};

   always_ff @(posedge ram_clk)
     if(ram_en) begin
        ram_block_addr_delay <= ram_block_addr;
        ram_lsb_addr_delay <= ram_lsb_addr;
        for (i = 0; i < BRAM_WIDTH/8; i=i+1)
          if(ram_we_full[i]) ram[ram_block_addr][i*8 +:8] <= ram_wrdata_full[i*8 +: 8];
     end

   assign ram_rddata_full = ram[ram_block_addr_delay];
   assign ram_rddata_shift = ram_lsb_addr_delay << (BRAM_OFFSET_BITS + 3); // avoid ISim error
   assign ram_rddata = ram_rddata_full >> ram_rddata_shift;

   initial $readmemh("boot.mem", ram);
`endif

   /////////////////////////////////////////////////////////////
   // SPI
   nasti_channel
     #(
       .ADDR_WIDTH  ( `ROCKET_PADDR_WIDTH       ),
       .DATA_WIDTH  ( `LOWRISC_IO_DAT_WIDTH     ))
   io_spi_lite();
   logic                       spi_irq;

`ifdef ADD_SPI
   wire                        spi_mosi_i, spi_mosi_o, spi_mosi_t;
   wire                        spi_miso_i, spi_miso_o, spi_miso_t;
   wire                        spi_sclk_i, spi_sclk_o, spi_sclk_t;
   wire                        spi_cs_i,   spi_cs_o,   spi_cs_t;

   axi_quad_spi_0 spi_i
     (
      .ext_spi_clk     ( clk                   ),
      .s_axi_aclk      ( clk                   ),
      .s_axi_aresetn   ( rstn                  ),
      .s_axi_araddr    ( io_spi_lite.ar_addr   ),
      .s_axi_arready   ( io_spi_lite.ar_ready  ),
      .s_axi_arvalid   ( io_spi_lite.ar_valid  ),
      .s_axi_awaddr    ( io_spi_lite.aw_addr   ),
      .s_axi_awready   ( io_spi_lite.aw_ready  ),
      .s_axi_awvalid   ( io_spi_lite.aw_valid  ),
      .s_axi_bready    ( io_spi_lite.b_ready   ),
      .s_axi_bresp     ( io_spi_lite.b_resp    ),
      .s_axi_bvalid    ( io_spi_lite.b_valid   ),
      .s_axi_rdata     ( io_spi_lite.r_data    ),
      .s_axi_rready    ( io_spi_lite.r_ready   ),
      .s_axi_rresp     ( io_spi_lite.r_resp    ),
      .s_axi_rvalid    ( io_spi_lite.r_valid   ),
      .s_axi_wdata     ( io_spi_lite.w_data    ),
      .s_axi_wready    ( io_spi_lite.w_ready   ),
      .s_axi_wstrb     ( io_spi_lite.w_strb    ),
      .s_axi_wvalid    ( io_spi_lite.w_valid   ),
      .io0_i           ( spi_mosi_i            ),
      .io0_o           ( spi_mosi_o            ),
      .io0_t           ( spi_mosi_t            ),
      .io1_i           ( spi_miso_i            ),
      .io1_o           ( spi_miso_o            ),
      .io1_t           ( spi_miso_t            ),
      .sck_i           ( spi_sclk_i            ),
      .sck_o           ( spi_sclk_o            ),
      .sck_t           ( spi_sclk_t            ),
      .ss_i            ( spi_cs_i              ),
      .ss_o            ( spi_cs_o              ),
      .ss_t            ( spi_cs_t              ),
      .ip2intc_irpt    ( spi_irq               )  // polling for now
      );

   // tri-state gate to protect SPI IOs

   OBUFT #(
      .DRIVE(12),   // Specify the output drive strength
      .IOSTANDARD("DEFAULT"), // Specify the output I/O standard
      .SLEW("SLOW") // Specify the output slew rate
   ) OBUFT_spi_mosi (
      .O(spi_mosi),     // Buffer output (connect directly to top-level port)
      .I(spi_mosi_o),     // Buffer input
      .T(spi_mosi_t)      // 3-state enable input 
   );

   assign spi_mosi_i = 1'b1;    // always in master mode

   IOBUF #(
      .DRIVE(12), // Specify the output drive strength
      .IBUF_LOW_PWR("TRUE"),  // Low Power - "TRUE", High Performance = "FALSE" 
      .IOSTANDARD("DEFAULT"), // Specify the I/O standard
      .SLEW("SLOW") // Specify the output slew rate
   ) IOBUF_spi_miso (
      .O(spi_miso_i),     // Buffer output
      .IO(spi_miso),   // Buffer inout port (connect directly to top-level port)
      .I(spi_miso_o),     // Buffer input
      .T(spi_miso_t)      // 3-state enable input, high=input, low=output
   );

   OBUFT #(
      .DRIVE(12),   // Specify the output drive strength
      .IOSTANDARD("DEFAULT"), // Specify the output I/O standard
      .SLEW("SLOW") // Specify the output slew rate
   ) OBUFT_spi_sclk (
      .O(spi_sclk),     // Buffer output (connect directly to top-level port)
      .I(spi_sclk_o),     // Buffer input
      .T(spi_sclk_t)      // 3-state enable input 
   );

   assign spi_sclk_i = 1'b1;    // always in master mode

   OBUFT #(
      .DRIVE(12),   // Specify the output drive strength
      .IOSTANDARD("DEFAULT"), // Specify the output I/O standard
      .SLEW("SLOW") // Specify the output slew rate
   ) OBUFT_spi_cs (
      .O(spi_cs),     // Buffer output (connect directly to top-level port)
      .I(spi_cs_o),     // Buffer input
      .T(spi_cs_t)      // 3-state enable input 
   );

   assign spi_cs_i = 1'b1;     // always in master mode

`else // !`ifdef ADD_SPI

   assign spi_irq = 1'b0;

`endif // !`ifdef ADD_SPI

   /////////////////////////////////////////////////////////////
   // UART or trace debugger
   nasti_channel
     #(
       .ADDR_WIDTH  ( `ROCKET_PADDR_WIDTH       ),
       .DATA_WIDTH  ( `LOWRISC_IO_DAT_WIDTH     ))
   io_uart_lite();
   logic                       uart_irq;

 `ifdef ENABLE_DEBUG
   // Debug MAM signals
   logic                               mam_req_valid;
   logic                               mam_req_ready;
   logic                               mam_req_rw;
   logic [`ROCKET_PADDR_WIDTH-1:0]     mam_req_addr;
   logic                               mam_req_burst;
   logic [13:0]                        mam_req_beats;
   logic                               mam_write_valid;
   logic [`ROCKET_MAM_IO_DWIDTH-1:0]   mam_write_data;
   logic [`ROCKET_MAM_IO_DWIDTH/8-1:0] mam_write_strb;
   logic                               mam_write_ready;
   logic                               mam_read_valid;
   logic [`ROCKET_MAM_IO_DWIDTH-1:0]   mam_read_data;
   logic                               mam_read_ready;

   // Debug ring connections
   dii_flit [1:0]                     debug_ring_start; // starting connector
   logic [1:0]                        debug_ring_start_ready;
   dii_flit [1:0]                     debug_ring_end; // ending connector
   logic [1:0]                        debug_ring_end_ready;

   debug_system
     #(
       .N_CORES          ( `ROCKET_NTILES          ),
       .MAM_DATA_WIDTH   ( `ROCKET_MAM_IO_DWIDTH   ),
       .MAM_ADDR_WIDTH   ( `ROCKET_PADDR_WIDTH     )
       )
   u_debug_system
     (
      .*,
      .uart_irq        (uart_irq),
      .uart_ar_addr    ( io_uart_lite.ar_addr   ),
      .uart_ar_ready   ( io_uart_lite.ar_ready  ),
      .uart_ar_valid   ( io_uart_lite.ar_valid  ),
      .uart_aw_addr    ( io_uart_lite.aw_addr   ),
      .uart_aw_ready   ( io_uart_lite.aw_ready  ),
      .uart_aw_valid   ( io_uart_lite.aw_valid  ),
      .uart_b_ready    ( io_uart_lite.b_ready   ),
      .uart_b_resp     ( io_uart_lite.b_resp    ),
      .uart_b_valid    ( io_uart_lite.b_valid   ),
      .uart_r_data     ( io_uart_lite.r_data    ),
      .uart_r_ready    ( io_uart_lite.r_ready   ),
      .uart_r_resp     ( io_uart_lite.r_resp    ),
      .uart_r_valid    ( io_uart_lite.r_valid   ),
      .uart_w_data     ( io_uart_lite.w_data    ),
      .uart_w_ready    ( io_uart_lite.w_ready   ),
      .uart_w_valid    ( io_uart_lite.w_valid   ),
      .rx              ( rxd                    ),
      .tx              ( txd                    ),
      .sys_rst         ( sys_rst                ),
      .cpu_rst         ( cpu_rst                ),
      .ring_out        ( debug_ring_start       ),
      .ring_out_ready  ( debug_ring_start_ready ),
      .ring_in         ( debug_ring_end         ),
      .ring_in_ready   ( debug_ring_end_ready   ),
      .req_valid       ( mam_req_valid          ),
      .req_ready       ( mam_req_ready          ),
      .req_rw          ( mam_req_rw             ),
      .req_addr        ( mam_req_addr           ),
      .req_burst       ( mam_req_burst          ),
      .req_beats       ( mam_req_beats          ),
      .write_valid     ( mam_write_valid        ),
      .write_ready     ( mam_write_ready        ),
      .write_data      ( mam_write_data         ),
      .write_strb      ( mam_write_strb         ),
      .read_valid      ( mam_read_valid         ),
      .read_data       ( mam_read_data          ),
      .read_ready      ( mam_read_ready         )
      );
 `else // !`ifdef ENABLE_DEBUG
   assign sys_rst = rst;
   assign cpu_rst = 1'b0;

  `ifdef ADD_UART
   axi_uart16550_0 uart_i
     (
      .s_axi_aclk      ( clk                    ),
      .s_axi_aresetn   ( rstn                   ),
      .s_axi_araddr    ( io_uart_lite.ar_addr  ),
      .s_axi_arready   ( io_uart_lite.ar_ready ),
      .s_axi_arvalid   ( io_uart_lite.ar_valid ),
      .s_axi_awaddr    ( io_uart_lite.aw_addr  ),
      .s_axi_awready   ( io_uart_lite.aw_ready ),
      .s_axi_awvalid   ( io_uart_lite.aw_valid ),
      .s_axi_bready    ( io_uart_lite.b_ready  ),
      .s_axi_bresp     ( io_uart_lite.b_resp   ),
      .s_axi_bvalid    ( io_uart_lite.b_valid  ),
      .s_axi_rdata     ( io_uart_lite.r_data   ),
      .s_axi_rready    ( io_uart_lite.r_ready  ),
      .s_axi_rresp     ( io_uart_lite.r_resp   ),
      .s_axi_rvalid    ( io_uart_lite.r_valid  ),
      .s_axi_wdata     ( io_uart_lite.w_data   ),
      .s_axi_wready    ( io_uart_lite.w_ready  ),
      .s_axi_wstrb     ( io_uart_lite.w_strb   ),
      .s_axi_wvalid    ( io_uart_lite.w_valid  ),
      .ip2intc_irpt    ( uart_irq               ),
      .freeze          ( 1'b0                   ),
      .rin             ( 1'b1                   ),
      .dcdn            ( 1'b1                   ),
      .dsrn            ( 1'b1                   ),
      .sin             ( rxd                    ),
      .sout            ( txd                    ),
      .ctsn            ( 1'b1                   ),
      .rtsn            (                        )
      );

  `else // !`ifdef ADD_UART

   assign uart_irq = 1'b0;

  `endif // !`ifdef ADD_UART

 `endif

   /////////////////////////////////////////////////////////////
   // Host for ISA regression

   nasti_channel
     #(
       .ADDR_WIDTH  ( `ROCKET_PADDR_WIDTH       ),
       .DATA_WIDTH  ( `LOWRISC_IO_DAT_WIDTH     ))
   io_host_lite();

 `ifdef ADD_HOST
   host_behav host
     (
      .clk          ( clk          ),
      .rstn         ( rstn         ),
      .nasti        ( io_host_lite )
      );
 `endif

   /////////////////////////////////////////////////////////////
   // IO crossbar

   localparam NUM_DEVICE = 4;

   // output of the IO crossbar
   nasti_channel
     #(
       .N_PORT      ( NUM_DEVICE                ),
       .ADDR_WIDTH  ( `ROCKET_PADDR_WIDTH       ),
       .DATA_WIDTH  ( `LOWRISC_IO_DAT_WIDTH     ))
   io_cbo_lite();

   nasti_channel ios_dmm4(), ios_dmm5(), ios_dmm6(), ios_dmm7(); // dummy channels

   nasti_channel_slicer #(NUM_DEVICE)
   io_slicer (.s(io_cbo_lite), .m0(io_host_lite), .m1(io_uart_lite), .m2(io_spi_lite),
              .m3(io_bram_lite), .m4(ios_dmm4), .m5(ios_dmm5), .m6(ios_dmm6), .m7(ios_dmm7));

   // the io crossbar
   nasti_crossbar
     #(
       .N_INPUT    ( 1                     ),
       .N_OUTPUT   ( NUM_DEVICE            ),
       .IB_DEPTH   ( 0                     ),
       .OB_DEPTH   ( 1                     ), // some IPs response only with data, which will cause deadlock in nasti_demux (no lock)
       .W_MAX      ( 1                     ),
       .R_MAX      ( 1                     ),
       .ADDR_WIDTH ( `ROCKET_PADDR_WIDTH   ),
       .DATA_WIDTH ( `LOWRISC_IO_DAT_WIDTH ),
       .LITE_MODE  ( 1                     )
       )
   io_crossbar
     (
      .*,
      .s ( io_lite     ),
      .m ( io_cbo_lite )
      );

 `ifdef ADD_HOST
   defparam io_crossbar.BASE0 = `DEV_MAP__io_ext_host__BASE ;
   defparam io_crossbar.MASK0 = `DEV_MAP__io_ext_host__MASK ;
 `endif

 `ifdef ADD_UART
   defparam io_crossbar.BASE1 = `DEV_MAP__io_ext_uart__BASE;
   defparam io_crossbar.MASK1 = `DEV_MAP__io_ext_uart__MASK;
 `endif

 `ifdef ADD_SPI
   defparam io_crossbar.BASE2 = `DEV_MAP__io_ext_spi__BASE;
   defparam io_crossbar.MASK2 = `DEV_MAP__io_ext_spi__MASK;
 `endif

 `ifdef ADD_BRAM
   defparam io_crossbar.BASE3 = `DEV_MAP__io_ext_bram__BASE;
   defparam io_crossbar.MASK3 = `DEV_MAP__io_ext_bram__MASK;
 `endif

   /////////////////////////////////////////////////////////////
   // the Rocket chip

   Top Rocket
     (
      .clk                           ( clk                                    ),
      .reset                         ( sys_rst                                ),
      .io_nasti_mem_aw_valid         ( mem_nasti.aw_valid                     ),
      .io_nasti_mem_aw_ready         ( mem_nasti.aw_ready                     ),
      .io_nasti_mem_aw_bits_id       ( mem_nasti.aw_id                        ),
      .io_nasti_mem_aw_bits_addr     ( mem_nasti.aw_addr                      ),
      .io_nasti_mem_aw_bits_len      ( mem_nasti.aw_len                       ),
      .io_nasti_mem_aw_bits_size     ( mem_nasti.aw_size                      ),
      .io_nasti_mem_aw_bits_burst    ( mem_nasti.aw_burst                     ),
      .io_nasti_mem_aw_bits_lock     ( mem_nasti.aw_lock                      ),
      .io_nasti_mem_aw_bits_cache    ( mem_nasti.aw_cache                     ),
      .io_nasti_mem_aw_bits_prot     ( mem_nasti.aw_prot                      ),
      .io_nasti_mem_aw_bits_qos      ( mem_nasti.aw_qos                       ),
      .io_nasti_mem_aw_bits_region   ( mem_nasti.aw_region                    ),
      .io_nasti_mem_aw_bits_user     ( mem_nasti.aw_user                      ),
      .io_nasti_mem_w_valid          ( mem_nasti.w_valid                      ),
      .io_nasti_mem_w_ready          ( mem_nasti.w_ready                      ),
      .io_nasti_mem_w_bits_data      ( mem_nasti.w_data                       ),
      .io_nasti_mem_w_bits_strb      ( mem_nasti.w_strb                       ),
      .io_nasti_mem_w_bits_last      ( mem_nasti.w_last                       ),
      .io_nasti_mem_w_bits_user      ( mem_nasti.w_user                       ),
      .io_nasti_mem_b_valid          ( mem_nasti.b_valid                      ),
      .io_nasti_mem_b_ready          ( mem_nasti.b_ready                      ),
      .io_nasti_mem_b_bits_id        ( mem_nasti.b_id                         ),
      .io_nasti_mem_b_bits_resp      ( mem_nasti.b_resp                       ),
      .io_nasti_mem_b_bits_user      ( mem_nasti.b_user                       ),
      .io_nasti_mem_ar_valid         ( mem_nasti.ar_valid                     ),
      .io_nasti_mem_ar_ready         ( mem_nasti.ar_ready                     ),
      .io_nasti_mem_ar_bits_id       ( mem_nasti.ar_id                        ),
      .io_nasti_mem_ar_bits_addr     ( mem_nasti.ar_addr                      ),
      .io_nasti_mem_ar_bits_len      ( mem_nasti.ar_len                       ),
      .io_nasti_mem_ar_bits_size     ( mem_nasti.ar_size                      ),
      .io_nasti_mem_ar_bits_burst    ( mem_nasti.ar_burst                     ),
      .io_nasti_mem_ar_bits_lock     ( mem_nasti.ar_lock                      ),
      .io_nasti_mem_ar_bits_cache    ( mem_nasti.ar_cache                     ),
      .io_nasti_mem_ar_bits_prot     ( mem_nasti.ar_prot                      ),
      .io_nasti_mem_ar_bits_qos      ( mem_nasti.ar_qos                       ),
      .io_nasti_mem_ar_bits_region   ( mem_nasti.ar_region                    ),
      .io_nasti_mem_ar_bits_user     ( mem_nasti.ar_user                      ),
      .io_nasti_mem_r_valid          ( mem_nasti.r_valid                      ),
      .io_nasti_mem_r_ready          ( mem_nasti.r_ready                      ),
      .io_nasti_mem_r_bits_id        ( mem_nasti.r_id                         ),
      .io_nasti_mem_r_bits_data      ( mem_nasti.r_data                       ),
      .io_nasti_mem_r_bits_resp      ( mem_nasti.r_resp                       ),
      .io_nasti_mem_r_bits_last      ( mem_nasti.r_last                       ),
      .io_nasti_mem_r_bits_user      ( mem_nasti.r_user                       ),
      .io_nasti_io_aw_valid          ( io_nasti.aw_valid                      ),
      .io_nasti_io_aw_ready          ( io_nasti.aw_ready                      ),
      .io_nasti_io_aw_bits_id        ( io_nasti.aw_id                         ),
      .io_nasti_io_aw_bits_addr      ( io_nasti.aw_addr                       ),
      .io_nasti_io_aw_bits_len       ( io_nasti.aw_len                        ),
      .io_nasti_io_aw_bits_size      ( io_nasti.aw_size                       ),
      .io_nasti_io_aw_bits_burst     ( io_nasti.aw_burst                      ),
      .io_nasti_io_aw_bits_lock      ( io_nasti.aw_lock                       ),
      .io_nasti_io_aw_bits_cache     ( io_nasti.aw_cache                      ),
      .io_nasti_io_aw_bits_prot      ( io_nasti.aw_prot                       ),
      .io_nasti_io_aw_bits_qos       ( io_nasti.aw_qos                        ),
      .io_nasti_io_aw_bits_region    ( io_nasti.aw_region                     ),
      .io_nasti_io_aw_bits_user      ( io_nasti.aw_user                       ),
      .io_nasti_io_w_valid           ( io_nasti.w_valid                       ),
      .io_nasti_io_w_ready           ( io_nasti.w_ready                       ),
      .io_nasti_io_w_bits_data       ( io_nasti.w_data                        ),
      .io_nasti_io_w_bits_strb       ( io_nasti.w_strb                        ),
      .io_nasti_io_w_bits_last       ( io_nasti.w_last                        ),
      .io_nasti_io_w_bits_user       ( io_nasti.w_user                        ),
      .io_nasti_io_b_valid           ( io_nasti.b_valid                       ),
      .io_nasti_io_b_ready           ( io_nasti.b_ready                       ),
      .io_nasti_io_b_bits_id         ( io_nasti.b_id                          ),
      .io_nasti_io_b_bits_resp       ( io_nasti.b_resp                        ),
      .io_nasti_io_b_bits_user       ( io_nasti.b_user                        ),
      .io_nasti_io_ar_valid          ( io_nasti.ar_valid                      ),
      .io_nasti_io_ar_ready          ( io_nasti.ar_ready                      ),
      .io_nasti_io_ar_bits_id        ( io_nasti.ar_id                         ),
      .io_nasti_io_ar_bits_addr      ( io_nasti.ar_addr                       ),
      .io_nasti_io_ar_bits_len       ( io_nasti.ar_len                        ),
      .io_nasti_io_ar_bits_size      ( io_nasti.ar_size                       ),
      .io_nasti_io_ar_bits_burst     ( io_nasti.ar_burst                      ),
      .io_nasti_io_ar_bits_lock      ( io_nasti.ar_lock                       ),
      .io_nasti_io_ar_bits_cache     ( io_nasti.ar_cache                      ),
      .io_nasti_io_ar_bits_prot      ( io_nasti.ar_prot                       ),
      .io_nasti_io_ar_bits_qos       ( io_nasti.ar_qos                        ),
      .io_nasti_io_ar_bits_region    ( io_nasti.ar_region                     ),
      .io_nasti_io_ar_bits_user      ( io_nasti.ar_user                       ),
      .io_nasti_io_r_valid           ( io_nasti.r_valid                       ),
      .io_nasti_io_r_ready           ( io_nasti.r_ready                       ),
      .io_nasti_io_r_bits_id         ( io_nasti.r_id                          ),
      .io_nasti_io_r_bits_data       ( io_nasti.r_data                        ),
      .io_nasti_io_r_bits_resp       ( io_nasti.r_resp                        ),
      .io_nasti_io_r_bits_last       ( io_nasti.r_last                        ),
      .io_nasti_io_r_bits_user       ( io_nasti.r_user                        ),
      .io_interrupt                  ( interrupt                              ),
 `ifdef ENABLE_DEBUG
      .io_debug_net_0_dii_in         ( debug_ring_start[0]                    ),
      .io_debug_net_0_dii_in_ready   ( debug_ring_start_ready[0]              ),
      .io_debug_net_1_dii_in         ( debug_ring_start[1]                    ),
      .io_debug_net_1_dii_in_ready   ( debug_ring_start_ready[1]              ),
      .io_debug_net_0_dii_out        ( debug_ring_end[0]                      ),
      .io_debug_net_0_dii_out_ready  ( debug_ring_end_ready[0]                ),
      .io_debug_net_1_dii_out        ( debug_ring_end[1]                      ),
      .io_debug_net_1_dii_out_ready  ( debug_ring_end_ready[1]                ),
      .io_debug_mam_req_ready        ( mam_req_ready                          ),
      .io_debug_mam_req_valid        ( mam_req_valid                          ),
      .io_debug_mam_req_bits_rw      ( mam_req_rw                             ),
      .io_debug_mam_req_bits_addr    ( mam_req_addr                           ),
      .io_debug_mam_req_bits_burst   ( mam_req_burst                          ),
      .io_debug_mam_req_bits_beats   ( mam_req_beats                          ),
      .io_debug_mam_wdata_ready      ( mam_write_ready                        ),
      .io_debug_mam_wdata_valid      ( mam_write_valid                        ),
      .io_debug_mam_wdata_bits_data  ( mam_write_data                         ),
      .io_debug_mam_wdata_bits_strb  ( mam_write_strb                         ),
      .io_debug_mam_rdata_ready      ( mam_read_ready                         ),
      .io_debug_mam_rdata_valid      ( mam_read_valid                         ),
      .io_debug_mam_rdata_bits_data  ( mam_read_data                          ),
 `endif
      .io_debug_rst                  ( rst                                    ),
      .io_cpu_rst                    ( cpu_rst                                )
      );

   // interrupt
   assign interrupt = {62'b0, spi_irq, uart_irq};

   // convert io_nasti to io_lite
   nasti_lite_bridge
     #(
       .ID_WIDTH          ( 1                     ),
       .ADDR_WIDTH        ( `ROCKET_PADDR_WIDTH   ),
       .NASTI_DATA_WIDTH  ( `ROCKET_IO_DAT_WIDTH  ),
       .LITE_DATA_WIDTH   ( `LOWRISC_IO_DAT_WIDTH )
       )
   io_bridge
     (
      .*,
      .nasti_s  ( io_nasti  ),
      .lite_m   ( io_lite   )
      );

endmodule // chip_top
