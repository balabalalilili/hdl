// ***************************************************************************
// ***************************************************************************
// Copyright 2020 (c) Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************
// This is the LVDS/DDR interface, note that overrange is independent of data path,
// software will not be able to relate overrange to a specific sample!

`timescale 1ns/100ps

module axi_ltc2387_if #(

  parameter   FPGA_TECHNOLOGY = 0,
  parameter   IO_DELAY_GROUP = "adc_if_delay_group",
  parameter   DELAY_REFCLK_FREQUENCY = 200,
  parameter   TWOLANES = 0,       // 0 for Single Lane, 1 for Two Lanes
  parameter   RESOLUTION = 16,    // 16 or 18 bits
  parameter   TCLKDCO = 2.3) (

  // adc interface

  input                   clock,
  input                   clk_in_p,
  input                   clk_in_n,
  input                   dco_p,
  input                   dco_n,
  input                   adc_da_in_p,
  input                   adc_da_in_n,
  input                   adc_db_in_p,
  input                   adc_db_in_n,
  output                  cnv,
  output                  clk_en,

  // interface outputs

  output  reg [31:0]      adc_data,
  output  reg             adc_status,

  // control signals

  input       [31:0]      samp_period,
  input       [31:0]      cnv_h_period,
  input       [31:0]      dco_phase_offset,
  input       [31:0]      dco_h_period,

  // delay control signals

  input                   up_clk,
  input       [ 8:0]      up_dld,
  input       [44:0]      up_dwdata,
  output      [44:0]      up_drdata,
  input                   delay_clk,
  input                   delay_rst,
  output                  delay_locked);

  // local wires and registers

  reg                     cnv_reg = 1'b0;
  reg                     dco = 1'b0;
  reg                     last_dco;
  reg                     last_dco_d;
  reg         [5:0]       num_dco = (RESOLUTION == 18) ?
                                      (TWOLANES) ? 'h5:'h9 :
                                      (TWOLANES) ? 'h4:'h8;
  reg         [5:0]       dco_en_cnt;
  reg         [5:0]       dco_in_cnt;
  reg                     clk_en_ctrl;
  reg       [31 :0]       period_cnt = 32'd0;
  reg                     two_lanes = TWOLANES;
  reg                     sync_pulse;
  reg  [RESOLUTION-1:0]   dac_data_s = 'b0;
  reg  [RESOLUTION+1:0]   adc_data_d ='b0;

  // internal registers

  reg         [8:0]       adc_data_p = 'd0;
  reg         [8:0]       adc_data_n = 'd0;

  // internal signals

  wire        [1:0]       rx_data_a_s;
  wire        [1:0]       rx_data_b_s;

  wire                    dco_s;

  assign cnv = cnv_reg;
  assign clk_en = clk_en_ctrl;
////////////////////////////////////////////////////////
// ADD RESET LOGIC
////////////////////////////////////////////////////////
  always @(posedge clock) begin
    if (period_cnt == samp_period) begin
      period_cnt <= 32'd0;
    end else begin
      period_cnt <= period_cnt + 1;
    end

    if (period_cnt == 0) begin
      cnv_reg <= 1'b1;
    end else if (period_cnt == cnv_h_period) begin
      cnv_reg <= 1'b0;
    end else begin
      cnv_reg <= cnv_reg;
    end

    if (period_cnt == dco_phase_offset) begin
      dco_en_cnt <= dco_h_period;
      clk_en_ctrl <= 1'b1;
    end else begin
      if (dco_en_cnt != 0) begin
        dco_en_cnt <= dco_en_cnt - 1'b1;
      end else begin
        clk_en_ctrl <= 1'b0;
      end
    end
  end

  always @(posedge dco_s) begin
    if (dco_in_cnt == dco_h_period) begin
      last_dco <= 1'b1;
      dco_in_cnt <= 0;
    end else begin
      dco_in_cnt <= dco_in_cnt + 1'b1;
      last_dco <= 1'b0;
    end
  end

  always @(posedge dco_s) begin
    if (two_lanes == 0) begin
      adc_data_d <= (adc_data_d << 2) | {{(RESOLUTION-2){1'b0}}, rx_data_a_s[1], rx_data_a_s[0]};
    end else begin
      adc_data_d <= (adc_data_d << 4) | {{(RESOLUTION-4){1'b0}}, rx_data_a_s[1], rx_data_b_s[1], rx_data_a_s[0], rx_data_b_s[0]};
    end
  end

  always @(posedge clock) begin
    last_dco_d <= last_dco;
    if (!last_dco_d & last_dco) begin
      if (two_lanes == 0) begin
        adc_data <= adc_data_d[RESOLUTION-1:0];
      end else begin
        if (RESOLUTION == 16) begin
          adc_data = adc_data_d[RESOLUTION-1:0];
        end else begin
          adc_data = adc_data_d[RESOLUTION+1:2];
        end
      end
    end else begin
      adc_data <= adc_data;
    end
  end

  // data interface

  ad_data_in #(
    .FPGA_TECHNOLOGY (FPGA_TECHNOLOGY),
    .IODELAY_CTRL (0),
    .IODELAY_GROUP (IO_DELAY_GROUP),
    .REFCLK_FREQUENCY (DELAY_REFCLK_FREQUENCY))
  i_adc_data_a (
    .rx_clk (dco_s),
    .rx_data_in_p (adc_da_in_p),
    .rx_data_in_n (adc_da_in_n),
    .rx_data_p (rx_data_a_s[1]),
    .rx_data_n (rx_data_a_s[0]),
    .up_clk (up_clk),
    .up_dld (up_dld),
    .up_dwdata (up_dwdata),
    .up_drdata (up_drdata),
    .delay_clk (delay_clk),
    .delay_rst (delay_rst),
    .delay_locked ());

  ad_data_in #(
    .FPGA_TECHNOLOGY (FPGA_TECHNOLOGY),
    .IODELAY_CTRL (0),
    .IODELAY_GROUP (IO_DELAY_GROUP),
    .REFCLK_FREQUENCY (DELAY_REFCLK_FREQUENCY))
  i_adc_data_b (
    .rx_clk (dco_s),
    .rx_data_in_p (adc_db_in_p),
    .rx_data_in_n (adc_db_in_n),
    .rx_data_p (rx_data_b_s[1]),
    .rx_data_n (rx_data_b_s[0]),
    .up_clk (up_clk),
    .up_dld (up_dld),
    .up_dwdata (up_dwdata),
    .up_drdata (up_drdata),
    .delay_clk (delay_clk),
    .delay_rst (delay_rst),
    .delay_locked ());

  // dco (clock)

  ad_data_clk
  i_dco (
    .rst (1'b0),
    .locked (),
    .clk_in_p (dco_p),
    .clk_in_n (dco_n),
    .clk (dco_s));


endmodule

// ***************************************************************************
// ***************************************************************************
