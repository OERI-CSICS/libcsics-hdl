


#include <verilator/verilated.h>
#include <verilator/verilated_vcd_c.h>
#include "Vvector_to_axis_tb.h"
int main(int argc, char* argv[]) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    auto top = std::make_unique<Vvector_to_axis_tb>();
    auto ctx = std::make_unique<VerilatedContext>();
    auto wv = std::make_unique<VerilatedVcdC>();
    top->trace(wv.get(), 2);
    wv->open("waveform.vcd");
    top->buf_in = (0x123456789abcdef) & ((1ULL << 44) - 1);
    top->valid_in = 1;
    top->m_axis_tready = 1;
    top->clk = 0;
    top->rst_n = 0;
    top->eval();
    top->rst_n = 1;
    while (ctx->time() < 10) {
        top->clk = !top->clk;
        ctx->timeInc(1);
        top->eval();
        wv->dump(ctx->time());
    }
    wv->close();


    return 0;
}
