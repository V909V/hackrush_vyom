`timescale 1ns / 1ps

module tb_ml_accelerator_testcases();

    // Inputs
    reg clk;
    reg resetn;
    reg pcpi_valid;
    reg [31:0] pcpi_insn;
    reg [31:0] pcpi_rs1;
    reg [31:0] pcpi_rs2;

    // Outputs
    wire pcpi_wr;
    wire [31:0] pcpi_rd;
    wire pcpi_wait;
    wire pcpi_ready;

    // Instantiate the Unit Under Test (UUT)
    ml_accelerator uut (
        .clk(clk),
        .resetn(resetn),
        .pcpi_valid(pcpi_valid),
        .pcpi_insn(pcpi_insn),
        .pcpi_rs1(pcpi_rs1),
        .pcpi_rs2(pcpi_rs2),
        .pcpi_wr(pcpi_wr),
        .pcpi_rd(pcpi_rd),
        .pcpi_wait(pcpi_wait),
        .pcpi_ready(pcpi_ready)
    );

    // Clock generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test vector array
    reg [31:0] vectors [0:30];
    integer i;

    // Variables to hold outputs for printing
    reg [31:0] res_relu, res_lrelu, res_sigm, res_tanh;
    real real_in, real_sigm, real_tanh;

    initial begin
        // Initialize Inputs
        resetn = 0;
        pcpi_valid = 0;
        pcpi_insn = 0;
        pcpi_rs1 = 0;
        pcpi_rs2 = 0; // rs2 is always 0 for our instructions

        // Load the 31 testcases 
        vectors[0]  = 32'h00000000; vectors[1]  = 32'h00000001;
        vectors[2]  = 32'hFFFFFFFF; vectors[3]  = 32'h00010000;
        vectors[4]  = 32'hFFFF0000; vectors[5]  = 32'h00008000;
        vectors[6]  = 32'hFFFF8000; vectors[7]  = 32'h00080000;
        vectors[8]  = 32'hFFF80000; vectors[9]  = 32'h7FFFFD71;
        vectors[10] = 32'h80000000; vectors[11] = 32'hFFFE4631;
        vectors[12] = 32'hFFFFC7B0; vectors[13] = 32'hFFFFA3E9;
        vectors[14] = 32'h0003C903; vectors[15] = 32'h000031A1;
        vectors[16] = 32'h00041025; vectors[17] = 32'h0001F7C9;
        vectors[18] = 32'hFFFFD07F; vectors[19] = 32'h0001235A;
        vectors[20] = 32'h0003CC47; vectors[21] = 32'h0001A8B7;
        vectors[22] = 32'h0002E8D3; vectors[23] = 32'hFFFBCADD;
        vectors[24] = 32'hFFFCFDFE; vectors[25] = 32'hFFFB7FD2;
        vectors[26] = 32'hFFFEDBCE; vectors[27] = 32'hFFFE48FC;
        vectors[28] = 32'hFFFC3F8E; vectors[29] = 32'h0001B8A5;
        vectors[30] = 32'hFFFCEFFB;

        #20 resetn = 1; // Release reset
        #10;

        $display("=====================================================================================================");
        $display("|   Input (Hex)  |   Input (Real) |      RELU      |     L_RELU     |  SIGM (Hex / Real) |  TANH (Hex / Real) |");
        $display("=====================================================================================================");

        // Loop through all test cases
        for (i = 0; i < 31; i = i + 1) begin
            pcpi_rs1 = vectors[i];
            real_in = $itor($signed(pcpi_rs1)) / 65536.0; // Convert Q16.16 to float

            // 1. Test RELU (funct7 = 0)
            pcpi_valid = 1;
            pcpi_insn = 32'h0000000B; 
            #10; 
            res_relu = pcpi_rd;

            // 2. Test L_RELU (funct7 = 1)
            pcpi_insn = 32'h0200000B; 
            #10; 
            res_lrelu = pcpi_rd;

            // 3. Test SIGM_APPROX (funct7 = 2)
            pcpi_insn = 32'h0400000B; 
            #10; 
            res_sigm = pcpi_rd;
            real_sigm = $itor($signed(res_sigm)) / 65536.0;

            // 4. Test TANH_APPROX (funct7 = 3)
            pcpi_insn = 32'h0600000B; 
            #10; 
            res_tanh = pcpi_rd;
            real_tanh = $itor($signed(res_tanh)) / 65536.0;

            pcpi_valid = 0;

            // Print the formatted results
            $display("|    %h    | %14.4f |    %h    |    %h    | %h ( %6.4f) | %h (%7.4f) |", 
                     pcpi_rs1, real_in, res_relu, res_lrelu, res_sigm, real_sigm, res_tanh, real_tanh);
            
            #10; // Wait before next vector
        end

        $display("=====================================================================================================");
        $display("Testbench Complete.");
        $finish;
    end

endmodule