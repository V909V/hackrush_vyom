module ml_accelerator (
    input clk, resetn,
    input             pcpi_valid,
    input      [31:0] pcpi_insn,
    input      [31:0] pcpi_rs1,
    input      [31:0] pcpi_rs2,
    output reg        pcpi_wr,
    output reg [31:0] pcpi_rd,
    output reg        pcpi_wait,
    output reg        pcpi_ready
);

    // Decode Opcode 1011 (binary: 0001011 = 7'h0B)
    wire is_custom = pcpi_valid && (pcpi_insn[6:0] == 7'b0001011);
    wire [2:0] funct3 = pcpi_insn[14:12];
    wire [6:0] funct7 = pcpi_insn[31:25]; 

    // ====================================================================
    // PART 1: CLOCKED HANDSHAKE LOGIC (Creates the 1-Cycle Delay)
    // ====================================================================
    always @(posedge clk) begin
        if (!resetn) begin
            pcpi_ready <= 1'b0;
            pcpi_wr    <= 1'b0;
            pcpi_wait  <= 1'b0;
        end else begin
            // SECURITY CHECK: Only answer if funct7 is 0, 1, 2, or 3!
            if (is_custom && funct3 == 3'b000 && funct7 <= 7'd3 && !pcpi_ready) begin 
                pcpi_ready <= 1'b1; // Wait 1 clock cycle, then pull High
                pcpi_wr    <= 1'b1; 
            end else begin
                // Turn off immediately after the pulse (or ignore invalid funct7)
                pcpi_ready <= 1'b0; 
                pcpi_wr    <= 1'b0; 
            end
        end
    end

    // ====================================================================
    // PART 2: COMBINATIONAL MATH LOGIC (Calculates instantly)
    // ====================================================================
    always @(*) begin
        // Default safe state for the data bus
        pcpi_rd = 32'b0; 

        // Ensure we are only answering to our custom opcode and funct3 = 000
        if (is_custom && funct3 == 3'b000) begin 
            
            case (funct7)
                7'd0: begin 
                    // --- RELU Logic ---
                    pcpi_rd = pcpi_rs1[31] ? 32'b0 : pcpi_rs1;
                end
                
                7'd1: begin 
                    // --- L_RELU Logic (Alpha = 0.125 / Shift by 3) ---
                    pcpi_rd = pcpi_rs1[31] ? { {3{pcpi_rs1[31]}}, pcpi_rs1[31:3] } : pcpi_rs1;
                end

                7'd2: begin 
                    // --- 7-Piece SIGM_APPROX Logic ---
                    if ($signed(pcpi_rs1) >= $signed(32'h00040000)) begin
                        // x >= 4.0 -> Cap at 1.0
                        pcpi_rd = 32'h00010000; 
                    end 
                    else if ($signed(pcpi_rs1) >= $signed(32'h00020000)) begin
                        // x in [2.0, 4.0) -> Slope 1/16 (>> 4), C = 0.75
                        pcpi_rd = { {4{pcpi_rs1[31]}}, pcpi_rs1[31:4] } + 32'h0000C000;
                    end 
                    else if ($signed(pcpi_rs1) >= $signed(32'h00010000)) begin
                        // x in [1.0, 2.0) -> Slope 1/8 (>> 3), C = 0.625
                        pcpi_rd = { {3{pcpi_rs1[31]}}, pcpi_rs1[31:3] } + 32'h0000A000;
                    end 
                    else if ($signed(pcpi_rs1) > $signed(32'hFFFF0000)) begin
                        // x in (-1.0, 1.0) -> Slope 1/4 (>> 2), C = 0.5 (Center)
                        pcpi_rd = { {2{pcpi_rs1[31]}}, pcpi_rs1[31:2] } + 32'h00008000;
                    end 
                    else if ($signed(pcpi_rs1) > $signed(32'hFFFE0000)) begin
                        // x in (-2.0, -1.0] -> Slope 1/8 (>> 3), C = 0.375
                        pcpi_rd = { {3{pcpi_rs1[31]}}, pcpi_rs1[31:3] } + 32'h00006000;
                    end 
                    else if ($signed(pcpi_rs1) > $signed(32'hFFFC0000)) begin
                        // x in (-4.0, -2.0] -> Slope 1/16 (>> 4), C = 0.25
                        pcpi_rd = { {4{pcpi_rs1[31]}}, pcpi_rs1[31:4] } + 32'h00004000;
                    end 
                    else begin
                        // x <= -4.0 -> Cap at 0.0
                        pcpi_rd = 32'h00000000; 
                    end
                end

                7'd3: begin
                    // --- 7-Piece TANH_APPROX Logic ---
                    if ($signed(pcpi_rs1) >= $signed(32'h00020000)) begin
                        // x >= 2.0 -> Cap at 1.0
                        pcpi_rd = 32'h00010000;
                    end
                    else if ($signed(pcpi_rs1) >= $signed(32'h00010000)) begin
                        // x in [1.0, 2.0) -> Slope 1/4 (>> 2), C = 0.5
                        pcpi_rd = { {2{pcpi_rs1[31]}}, pcpi_rs1[31:2] } + 32'h00008000;
                    end
                    else if ($signed(pcpi_rs1) >= $signed(32'h00008000)) begin
                        // x in [0.5, 1.0) -> Slope 1/2 (>> 1), C = 0.25
                        pcpi_rd = { {1{pcpi_rs1[31]}}, pcpi_rs1[31:1] } + 32'h00004000;
                    end
                    else if ($signed(pcpi_rs1) > $signed(32'hFFFF8000)) begin
                        // x in (-0.5, 0.5) -> Slope 1 (Pass-through)
                        pcpi_rd = pcpi_rs1;
                    end
                    else if ($signed(pcpi_rs1) > $signed(32'hFFFF0000)) begin
                        // x in (-1.0, -0.5] -> Slope 1/2 (>> 1), C = -0.25
                        pcpi_rd = { {1{pcpi_rs1[31]}}, pcpi_rs1[31:1] } + 32'hFFFFC000;
                    end
                    else if ($signed(pcpi_rs1) > $signed(32'hFFFE0000)) begin
                        // x in (-2.0, -1.0] -> Slope 1/4 (>> 2), C = -0.5
                        pcpi_rd = { {2{pcpi_rs1[31]}}, pcpi_rs1[31:2] } + 32'hFFFF8000;
                    end
                    else begin
                        // x <= -2.0 -> Cap at -1.0
                        pcpi_rd = 32'hFFFF0000;
                    end
                end

                default: begin
                    // Fallback for unhandled funct7
                    pcpi_rd = 32'b0;
                end
            endcase
        end
    end
endmodule