# ip

source ../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl

adi_ip_create axi_ltc2387
adi_ip_files axi_ltc2387 [list \
  "$ad_hdl_dir/library/common/ad_rst.v" \
  "$ad_hdl_dir/library/xilinx/common/ad_data_clk.v" \
  "$ad_hdl_dir/library/xilinx/common/ad_data_in.v" \
  "$ad_hdl_dir/library/common/up_clock_mon.v" \
  "$ad_hdl_dir/library/common/up_delay_cntrl.v" \
  "$ad_hdl_dir/library/common/up_axi.v" \
  "$ad_hdl_dir/library/xilinx/common/ad_rst_constr.xdc" \
  "$ad_hdl_dir/library/xilinx/common/up_clock_mon_constr.xdc" \
  "axi_ltc2387_if.v" \
  "axi_ltc2387.v" ]

adi_ip_properties axi_ltc2387

adi_ip_add_core_dependencies { \
	analog.com:user:axi_custom_control:1.0 \
}

#adi_init_bd_tcl
#adi_ip_bd axi_ltc2387 "bd/bd.tcl"

#set_property driver_value 0 [ipx::get_ports *dovf* -of_objects [ipx::current_core]]

ipx::infer_bus_interface adc_clk xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface delay_clk xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface adc_clk_in_p xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface adc_clk_in_n xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface adc_rst xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]

#adi_add_auto_fpga_spec_params
ipx::create_xgui_files [ipx::current_core]

ipx::save_core [ipx::current_core]
