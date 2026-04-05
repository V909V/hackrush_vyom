module system_top (
    input clk,
    input resetn,
    output trap
);

    // --- PCPI Interface Wires ---
    // These wires act as the "bridge" between the CPU and your Accelerator
    wire        pcpi_valid;
    wire [31:0] pcpi_insn;
    wire [31:0] pcpi_rs1;
    wire [31:0] pcpi_rs2;
    wire        pcpi_wr;
    wire [31:0] pcpi_rd;
    wire        pcpi_wait;
    wire        pcpi_ready;

    // --- Memory Interface Wires (Dummy connections for Synthesis) ---
    wire        mem_valid;
    wire        mem_ready = 1'b1; // Always ready for synthesis purposes
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    reg  [31:0] mem_rdata;

    // --- 1. Instantiate the PicoRV32 CPU ---
    (* dont_touch = "yes" *)
    picorv32 #(
        .ENABLE_PCPI(1),        // CRITICAL: Enables the coprocessor port
        .ENABLE_MUL(0),         // We use our accelerator for math
        .ENABLE_DIV(0),
        .COMPRESSED_ISA(0)
    ) cpu_inst (
        .clk         (clk),
        .resetn      (resetn),
        .trap        (trap),
        // PCPI Connections
        .pcpi_valid  (pcpi_valid),
        .pcpi_insn   (pcpi_insn),
        .pcpi_rs1    (pcpi_rs1),
        .pcpi_rs2    (pcpi_rs2),
        .pcpi_wr     (pcpi_wr),
        .pcpi_rd     (pcpi_rd),
        .pcpi_wait   (pcpi_wait),
        .pcpi_ready  (pcpi_ready),
        // Memory Connections (Basic wiring to prevent pruning)
        .mem_valid   (mem_valid),
        .mem_ready   (mem_ready),
        .mem_addr    (mem_addr),
        .mem_wdata   (mem_wdata),
        .mem_wstrb   (mem_wstrb),
        .mem_rdata   (mem_rdata)
    );

    // --- 2. Instantiate your ML Accelerator ---
    (* dont_touch = "yes" *)
    ml_accelerator accel_inst (
        .clk         (clk),
        .resetn      (resetn),
        .pcpi_valid  (pcpi_valid),
        .pcpi_insn   (pcpi_insn),
        .pcpi_rs1    (pcpi_rs1),
        .pcpi_rs2    (pcpi_rs2),
        .pcpi_wr     (pcpi_wr),
        .pcpi_rd     (pcpi_rd),
        .pcpi_wait   (pcpi_wait),
        .pcpi_ready  (pcpi_ready)
    );

endmodule