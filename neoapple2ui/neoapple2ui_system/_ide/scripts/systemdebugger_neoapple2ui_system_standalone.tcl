# Usage with Vitis IDE:
# In Vitis IDE create a Single Application Debug launch configuration,
# change the debug type to 'Attach to running target' and provide this 
# tcl script in 'Execute Script' option.
# Path of this script: D:\Work\FPGA\rtl-toys\neoapple2ui\neoapple2ui_system\_ide\scripts\systemdebugger_neoapple2ui_system_standalone.tcl
# 
# 
# Usage with xsct:
# To debug using xsct, launch xsct and run below command
# source D:\Work\FPGA\rtl-toys\neoapple2ui\neoapple2ui_system\_ide\scripts\systemdebugger_neoapple2ui_system_standalone.tcl
# 
connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~"APU*"}
rst -system
after 3000
targets -set -filter {jtag_cable_name =~ "Xilinx PYNQ-Z1 003017B04EB1A" && level==0 && jtag_device_ctx=="jsn-Xilinx PYNQ-Z1-003017B04EB1A-23727093-0"}
fpga -file D:/Work/FPGA/rtl-toys/neoapple2ui/neoapple2ui/_ide/bitstream/neoapple2.bit
targets -set -nocase -filter {name =~"APU*"}
loadhw -hw D:/Work/FPGA/rtl-toys/neoapple2ui/neoapple2/export/neoapple2/hw/neoapple2.xsa -mem-ranges [list {0x40000000 0xbfffffff}] -regs
configparams force-mem-access 1
targets -set -nocase -filter {name =~"APU*"}
source D:/Work/FPGA/rtl-toys/neoapple2ui/neoapple2ui/_ide/psinit/ps7_init.tcl
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "*A9*#0"}
dow D:/Work/FPGA/rtl-toys/neoapple2ui/neoapple2ui/Debug/neoapple2ui.elf
configparams force-mem-access 0
targets -set -nocase -filter {name =~ "*A9*#0"}
con
