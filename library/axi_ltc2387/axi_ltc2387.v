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

`timescale 1ns/100ps

module axi_ltc2387 #(

  parameter ID = 0,
  parameter FPGA_TECHNOLOGY = 0,
  parameter FPGA_FAMILY = 0,
  parameter SPEED_GRADE = 0,
  parameter DEV_PACKAGE = 0,
  parameter ADC_DATAPATH_DISABLE = 0,
  parameter IO_DELAY_GROUP = "adc_if_delay_group") (

  // adc interface

  input                   clock,
  input                   dco_p,
  input                   dco_n,
  input                   adc_da_in_p,
  input                   adc_da_in_n,
  input                   adc_db_in_p,
  input                   adc_db_in_n,
  output                  cnv,
  output                  clk_en,

  // delay interface

  input                   delay_clk,

  // dma interface

  output                  adc_clk,
//  output                  adc_rst,
//  output                  adc_valid,
//  output                  adc_enable,
  output      [31:0]      adc_data,
//  input                   adc_dovf,

  // axi interface

  input                   s_axi_aclk,
  input                   s_axi_aresetn,
  input                   s_axi_awvalid,
  input       [15:0]      s_axi_awaddr,
  output                  s_axi_awready,
  input                   s_axi_wvalid,
  input       [31:0]      s_axi_wdata,
  input       [ 3:0]      s_axi_wstrb,
  output                  s_axi_wready,
  output                  s_axi_bvalid,
  output      [ 1:0]      s_axi_bresp,
  input                   s_axi_bready,
  input                   s_axi_arvalid,
  input       [15:0]      s_axi_araddr,
  output                  s_axi_arready,
  output                  s_axi_rvalid,
  output      [ 1:0]      s_axi_rresp,
  output      [31:0]      s_axi_rdata,
  input                   s_axi_rready,
  input       [ 2:0]      s_axi_awprot,
  input       [ 2:0]      s_axi_arprot);


  // internal registers

  reg     [31:0]  up_rdata = 'd0;
  reg             up_wack = 'd0;
  reg             up_rack = 'd0;

  // internal clocks & resets

  wire            up_rstn;
  wire            up_clk;
  wire            delay_rst;

  // internal signals

  wire    [17:0]  adc_data_s;
  wire            adc_status_s;
  wire    [ 8:0]  up_dld_s;
  wire    [44:0]  up_dwdata_s;
  wire    [44:0]  up_drdata_s;
  wire            delay_locked_s;
  wire    [13:0]  up_raddr_s;
  wire    [31:0]  up_rdata_s[0:1];
  wire            up_rack_s[0:1];
  wire            up_wack_s[0:1];
  wire            up_wreq_s;
  wire    [13:0]  up_waddr_s;
  wire    [31:0]  up_wdata_s;
  wire            up_rreq_s;

  // signal name changes

  assign up_clk = s_axi_aclk;
  assign up_rstn = s_axi_aresetn;

  // processor read interface

  always @(negedge up_rstn or posedge up_clk) begin
    if (up_rstn == 0) begin
      up_rdata <= 'd0;
      up_rack <= 'd0;
      up_wack <= 'd0;
    end else begin
      up_rdata <= up_rdata_s[0] | up_rdata_s[1];
      up_rack <= up_rack_s[0] | up_rack_s[1];
      up_wack <= up_wack_s[0] | up_wack_s[1];
    end
  end

  // device interface

  axi_ltc2387_if #(
    .FPGA_TECHNOLOGY (FPGA_TECHNOLOGY),
    .IO_DELAY_GROUP (IO_DELAY_GROUP))
  i_if (
    .clock (clock),
    .adc_da_in_p (adc_da_in_p),
    .adc_da_in_n (adc_da_in_n),
    .adc_db_in_p (adc_db_in_p),
    .adc_db_in_n (adc_db_in_n),
    .dco_p (dco_p),
    .dco_n (dco_n),
    .cnv (cnv),
    .clk_en (clk_en),
    //.adc_clk (adc_clk),
    .adc_data (adc_data_s),
    .adc_status (adc_status_s),
    .samp_period (reg_control_0),
    .cnv_h_period (reg_control_1),
    .dco_phase_offset (reg_control_2),
    .dco_h_period (reg_control_3),
    .up_clk (up_clk),
    .up_dld (up_dld_s),
    .up_dwdata (up_dwdata_s),
    .up_drdata (up_drdata_s),
    .delay_clk (delay_clk),
    .delay_rst (delay_rst),
    .delay_locked (delay_locked_s));

  // adc delay control

  up_delay_cntrl #(.DATA_WIDTH(9), .BASE_ADDRESS(6'h02)) i_delay_cntrl (
    .delay_clk (delay_clk),
    .delay_rst (delay_rst),
    .delay_locked (delay_locked_s),
    .up_dld (up_dld_s),
    .up_dwdata (up_dwdata_s),
    .up_drdata (up_drdata_s),
    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack_s[1]),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata_s[1]),
    .up_rack (up_rack_s[1]));

  axi_custom_control #(
    .STAND_ALONE (0),
    .ADDR_OFFSET (0),
    .N_CONTROL_REG (4),
    .N_STATUS_REG (4)
  ) i_custom_control (
    .clk (clock),
    .reg_status_0 (adc_status_s),
    .reg_status_1 (32'd0),
    .reg_status_2 (32'd0),
    .reg_status_3 (32'd0),
    .reg_control_0 (reg_control_0),
    .reg_control_1 (reg_control_1),
    .reg_control_2 (reg_control_2),
    .reg_control_3 (reg_control_3),
    //.s_axi_aclik (1'd0),
    //.s_axi_aresetn (1'd0),
    //.s_axi_awvalid (1'd0),
    //.s_axi_awaddr (7'd0),
    //.s_axi_awprot (3'd0),
    //.s_axi_wvalid (1'd0),
    //.s_axi_wdata (32'd0),
    //.s_axi_wstrb (4'd0),
    //.s_axi_bready (1'd0),
    //.s_axi_arvalid (1'd0),
    //.s_axi_araddr (7'd0),
    //.s_axi_arprot (3'd0),
    //.s_axi_rready (1'd0),
    //.up_wreq_ext (1'd0),
    //.up_waddr_ext (16'd0),
    //.up_wdata_ext (32'd0),
    //.up_rreq_ext (1'd0),
    //.up_raddr_ext (16'd0),
    .up_rstn_ext (up_rstn),
    .up_clk_ext (up_clk),
    .up_wreq_ext (up_wreq_s),
    .up_waddr_ext (up_waddr_s),
    .up_wdata_ext (up_wdata_s),
    .up_wack_ext (up_wack_s[0]),
    .up_rreq_ext (up_rreq_s),
    .up_raddr_ext (up_raddr_s),
    .up_rdata_ext (up_rdata_s[0]),
    .up_rack_ext (up_rack_s[0]));

  // up bus interface

  up_axi i_up_axi (
    .up_rstn (up_rstn),
    .up_clk (up_clk),
    .up_axi_awvalid (s_axi_awvalid),
    .up_axi_awaddr (s_axi_awaddr),
    .up_axi_awready (s_axi_awready),
    .up_axi_wvalid (s_axi_wvalid),
    .up_axi_wdata (s_axi_wdata),
    .up_axi_wstrb (s_axi_wstrb),
    .up_axi_wready (s_axi_wready),
    .up_axi_bvalid (s_axi_bvalid),
    .up_axi_bresp (s_axi_bresp),
    .up_axi_bready (s_axi_bready),
    .up_axi_arvalid (s_axi_arvalid),
    .up_axi_araddr (s_axi_araddr),
    .up_axi_arready (s_axi_arready),
    .up_axi_rvalid (s_axi_rvalid),
    .up_axi_rresp (s_axi_rresp),
    .up_axi_rdata (s_axi_rdata),
    .up_axi_rready (s_axi_rready),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata),
    .up_rack (up_rack));

endmodule

// ***************************************************************************
// ***************************************************************************

