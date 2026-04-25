
cmake_minimum_required(VERSION 3.15)
project(verilator_tb)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
find_package(Verilator REQUIRED HINTS $ENV{VERILATOR_ROOT})
add_executable(verilator_tb sim_main.cpp)
set(SV_SOURCES 
    ../rtl/modules/vector_to_axis.sv
    ../rtl/interfaces/axi4s_if.sv
)
verilate(
    verilator_tb
    SOURCES tbs/vector_to_axis_tb.sv ${SV_SOURCES}
    TRACE_VCD
)
