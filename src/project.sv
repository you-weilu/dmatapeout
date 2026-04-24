/*
 * Copyright (c) 2026 You-wei (Terry) Lu
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_youweiterrylu (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  dma_top u_dma (
      .clk                    (clk),
      .rst_n                  (rst_n),
      .spi_sclk               (ui_in[0]),
      .spi_mosi               (ui_in[1]),
      .spi_csn                (ui_in[2]),
      .spi_miso               (uo_out[0]),
      .irq                    (uo_out[1]),
      .probe_fetch_req_valid  (uo_out[2]),
      .probe_df_in_wr_en      (uo_out[3]),
      .probe_dm_wr_en         (uo_out[4]),
      .probe_dm_instr_rw      (uo_out[5]),
      .probe_ring_empty       (uo_out[6]),
      .probe_busy             (uo_out[7]),
      .probe_rm_df_addr_lo    (uio_out)
  );

  assign uio_oe = 8'hFF;

  wire _unused = &{ena, ui_in[7:3], uio_in, 1'b0};

endmodule
