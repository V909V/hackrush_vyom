`timescale 1ns / 1ps

module tb_system_final();
    reg clk;
    reg resetn;
    wire trap;

    // 1. Instantiate System Top
    system_top uut (
        .clk(clk),
        .resetn(resetn),
        .trap(trap)
    );

    // 2. Memory Array (256KB)
    reg [31:0] ram [0:65535]; 
    integer i;

    // 3. Initialize Memory
    initial begin
        // Safety Net: Fill entire RAM with NOPs (0x00000013) to prevent X-state crashes
        for (i = 0; i < 65536; i = i + 1) begin
            ram[i] = 32'h00000013;
        end
        
        // Load the C program
        $readmemh("firmware.hex", ram);
        
        // Boot Sanity Check
        $display("----------------------------------");
        $display("BOOT CHECK: RAM[0] is %h", ram[0]);
        if (ram[0] === 32'h00000013) begin
             $display("WARNING: firmware.hex did not overwrite RAM[0]! Check file path.");
        end else begin
             $display("SUCCESS: Firmware loaded properly.");
        end
        $display("----------------------------------");
    end

// 4. Memory Read Logic (Forced Zero-Delay + Address Wrapping)
    // The "& 16'hFFFF" forces the address to stay inside our 65536-word array
    wire [31:0] tb_rdata_wire = ram[(uut.cpu_inst.mem_addr >> 2) & 16'hFFFF];
    wire tb_ready_wire = uut.cpu_inst.mem_valid;

    initial begin
        force uut.cpu_inst.mem_rdata = tb_rdata_wire;
        force uut.cpu_inst.mem_ready = tb_ready_wire;
    end

    // 5. Memory Write Logic (Synchronous + Address Wrapping)
    always @(posedge clk) begin
        if (uut.cpu_inst.mem_valid && uut.cpu_inst.mem_wstrb != 0) begin
            ram[(uut.cpu_inst.mem_addr >> 2) & 16'hFFFF] <= uut.cpu_inst.mem_wdata;
        end
    end
    // 6. Clock Generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // 7. Reset and Timeout
    initial begin
        resetn = 0;
        #100 resetn = 1; 
        #5000000 $finish; // 5ms maximum runtime
    end

    // 8. Trap Detection (End of Program)
    always @(posedge clk) begin
        if (resetn && trap) begin
            $display("----------------------------------");
            $display("TRAP DETECTED! C Code finished successfully.");
            $display("Time: %0t", $time);
            $display("----------------------------------");
            $finish;
        end
    end

// 9. Step-by-Step Execution Trace (First 20 Instructions)
    integer instr_count = 0;
    always @(posedge clk) begin
        if (resetn && uut.cpu_inst.mem_ready && uut.cpu_inst.mem_valid) begin
            if (instr_count < 30) begin
                $display("STEP %0d | PC: %h | DATA: %h", instr_count, uut.cpu_inst.reg_pc, uut.cpu_inst.mem_rdata);
                instr_count = instr_count + 1;
            end
        end
    end
// ---------------------------------------------------------
    // THE FINAL FIX: Clear 'X' states from CPU Registers
    // ---------------------------------------------------------
    initial begin
        #1; // Wait 1ns for Vivado to build the CPU module
        
        // 1. Wipe all 32 internal RISC-V registers to 0
        for (i = 0; i < 32; i = i + 1) begin
            uut.cpu_inst.cpuregs[i] = 32'h00000000; 
        end
        
        // 2. Set the Stack Pointer (Register x2) to the top of our RAM array
        // This gives your C code a safe place to store its variables!
        uut.cpu_inst.cpuregs[2] = 32'h0003FFFC; 
    end
endmodule