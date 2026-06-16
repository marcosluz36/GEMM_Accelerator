# ==============================
# Vivado project build script
# Board: Arty A7-100T
# ==============================

#========================
# PROJECT CONFIGURATIONS
#========================
set PROJECT_NAME "gemm_accelerator"
set TOP_MODULE   "fpga_core"
set PART_NAME    "xc7a100tcsg324-1"

set XDC_DIR      "constraints"
set PROJECT_DIR  "build"
set RTL_DIR      "rtl"
set IP_DIR       "ip"

set BOARD_CLK     100.000
set SYS_CLK       100.000
set DDR3_REF_CLK  200.000
set ETH_PHY_CLK   25.000

set MIG_PRJ_FILE  "$IP_DIR/mig_7series_0.prj"

#========================
# RECURSIVE FILE SEARCH
#========================
proc find_files {dir patterns} {
    set files {}

    foreach pattern $patterns {
        foreach f [glob -nocomplain -directory $dir -types f $pattern] {
            lappend files [file normalize $f]
        }
    }

    foreach d [glob -nocomplain -directory $dir -types d *] {
        foreach f [find_files $d $patterns] {
            lappend files $f
        }
    }

    return $files

#========================
# FILE PATHS
#========================
set ROOT_DIR [pwd]
}

set IP_DIR       [file normalize $IP_DIR]
set RTL_DIR      [file normalize $RTL_DIR]
set XDC_DIR      [file normalize $XDC_DIR]
set PROJECT_DIR  [file normalize $PROJECT_DIR]
set MIG_PRJ_FILE [file normalize $MIG_PRJ_FILE]

file mkdir $PROJECT_DIR
cd $PROJECT_DIR

if {[file exists $PROJECT_NAME]} {
    file delete -force $PROJECT_NAME
}

create_project $PROJECT_NAME $PROJECT_NAME -part $PART_NAME

#========================
# ADD PROJECT FILES
#========================
set RTL_FILES [concat \
    [find_files $RTL_DIR {"*.v" "*.sv"}]
]

set XDC_FILES [find_files $XDC_DIR {"*.xdc"}]

puts "RTL files: [llength $RTL_FILES]"
puts "XDC files: [llength $XDC_FILES]"

add_files -fileset sources_1 -norecurse $RTL_FILES
add_files -fileset constrs_1 -norecurse $XDC_FILES

foreach f $RTL_FILES {
    if {[string match "*.sv" $f]} {
        set_property file_type SystemVerilog [get_files $f]
    }
}

#========================
# GENERATE IPs
#========================

puts "Creating clk_wiz_ddr..."

create_ip \
    -name clk_wiz \
    -vendor xilinx.com \
    -library ip \
    -module_name clk_wiz_0

set_property -dict [list \
    CONFIG.PRIM_IN_FREQ               $BOARD_CLK \
    CONFIG.NUM_OUT_CLKS               {3} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $SYS_CLK \
    CONFIG.CLKOUT2_USED               {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ $DDR3_REF_CLK \
    CONFIG.CLKOUT3_USED               {true} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ $ETH_PHY_CLK \
    CONFIG.USE_RESET                  {true} \
    CONFIG.RESET_TYPE                 {ACTIVE_HIGH} \
] [get_ips clk_wiz_0]

generate_target all [get_ips clk_wiz_0]

puts "Creating mig_7series_0..."

if {![file exists $MIG_PRJ_FILE]} {
    puts "ERROR: MIG project file not found:"
    error "Missing MIG .prj file"
}

create_ip \
    -name mig_7series \
    -vendor xilinx.com \
    -library ip \
    -module_name mig_7series_0

set_property -dict [list \
    CONFIG.XML_INPUT_FILE $MIG_PRJ_FILE \
] [get_ips mig_7series_0]

generate_target all [get_ips mig_7series_0]

puts "Creating axis_data_fifo_0..."

create_ip \
    -name axis_data_fifo \
    -vendor xilinx.com \
    -library ip \
    -module_name axis_data_fifo_0

# Configure IP
set_property -dict [list \
    CONFIG.TDATA_NUM_BYTES       {16} \
    CONFIG.FIFO_DEPTH            {16} \
    CONFIG.HAS_TLAST             {1} \
    CONFIG.HAS_TKEEP             {0} \
    CONFIG.HAS_TSTRB             {0} \
    CONFIG.IS_ACLK_ASYNC         {1} \
    CONFIG.SYNCHRONIZATION_STAGES {2} \
    CONFIG.FIFO_MEMORY_TYPE      {auto} \
] [get_ips axis_data_fifo_0]

# Generate IP products
generate_target all [get_ips axis_data_fifo_0]

puts "Creating axis_data_fifo_1..."

create_ip \
    -name axis_data_fifo \
    -vendor xilinx.com \
    -library ip \
    -module_name axis_data_fifo_1

# Configure IP
set_property -dict [list \
    CONFIG.TDATA_NUM_BYTES       {6} \
    CONFIG.FIFO_DEPTH            {16} \
    CONFIG.HAS_TLAST             {0} \
    CONFIG.HAS_TKEEP             {0} \
    CONFIG.HAS_TSTRB             {0} \
    CONFIG.IS_ACLK_ASYNC         {1} \
    CONFIG.SYNCHRONIZATION_STAGES {2} \
    CONFIG.FIFO_MEMORY_TYPE      {auto} \
] [get_ips axis_data_fifo_1]

# Generate IP products
generate_target all [get_ips axis_data_fifo_1]


puts "Creating ila_0 system_debug IP..."

create_ip \
    -name ila \
    -vendor xilinx.com \
    -library ip \
    -module_name ila_0

set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {31} \
    CONFIG.C_DATA_DEPTH {8192} \
    CONFIG.C_PROBE0_WIDTH {1} \
    CONFIG.C_PROBE1_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {8} \
    CONFIG.C_PROBE3_WIDTH {1} \
    CONFIG.C_PROBE4_WIDTH {16} \
    CONFIG.C_PROBE5_WIDTH {1} \
    CONFIG.C_PROBE6_WIDTH {1} \
    CONFIG.C_PROBE7_WIDTH {1} \
    CONFIG.C_PROBE8_WIDTH {8} \
    CONFIG.C_PROBE9_WIDTH {1} \
    CONFIG.C_PROBE10_WIDTH {1} \
    CONFIG.C_PROBE11_WIDTH {1} \
    CONFIG.C_PROBE12_WIDTH {128} \
    CONFIG.C_PROBE13_WIDTH {1} \
    CONFIG.C_PROBE14_WIDTH {1} \
    CONFIG.C_PROBE15_WIDTH {1} \
    CONFIG.C_PROBE16_WIDTH {128} \
    CONFIG.C_PROBE17_WIDTH {1} \
    CONFIG.C_PROBE18_WIDTH {1} \
    CONFIG.C_PROBE19_WIDTH {1} \
    CONFIG.C_PROBE20_WIDTH {1} \
    CONFIG.C_PROBE21_WIDTH {1} \
    CONFIG.C_PROBE22_WIDTH {1} \
    CONFIG.C_PROBE23_WIDTH {1} \
    CONFIG.C_PROBE24_WIDTH {1} \
    CONFIG.C_PROBE25_WIDTH {1} \
    CONFIG.C_PROBE26_WIDTH {3}
] [get_ips ila_0]

generate_target all [get_ips ila_0]

#========================
# SET TOP MODULE
#========================
set_property top $TOP_MODULE [get_filesets sources_1]
update_compile_order -fileset sources_1

#========================
# SAVE PROJECT
#========================
save_project $PROJECT_NAME -force

puts "=========================================="
puts "Project created successfully."
puts "Top module: $TOP_MODULE"
puts "Part:       $PART_NAME"
puts "IPs:"
puts "  - clk_wiz_0"
puts "  - mig_7series_0"