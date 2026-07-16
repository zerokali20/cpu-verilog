// CO2070 Lab 6 – Computer Architecture
// Original authors : Group 38
// E/22/184 K.P.B.P. Karunanayake , E/22/353 G.K.G. Gayasha Sandeepa
// Modified for Lab 6 : cache integration

// Port additions vs cpu.v:
//   MEM_READ      (out) – asserted when CPU wants a memory read
//   MEM_WRITE     (out) – asserted when CPU wants a memory write
//   MEM_ADDRESS   (out) – byte address for the access (= ALURESULT)
//   MEM_WRITEDATA (out) – data the CPU wants to store (= REGOUT1)
//   MEM_READDATA  (in)  – data returned by the cache on a hit/fetch
//   MEM_BUSYWAIT  (in)  – cache stalls CPU while this is high
// ============================================================
`timescale 1ns/100ps

//ALU functional units
module FORWARD(DATA2, RESULT); //Forward function - passes DATA2 directly to the output
    input  [7:0] DATA2;
    output reg [7:0] RESULT; 
    always @(*) #1 RESULT = DATA2;        //one time unit delay is added
endmodule

module ADD(DATA1, DATA2, RESULT);//Add funcion - performs addition on DATA1 and DATA2
    input  [7:0] DATA1, DATA2;
    output reg [7:0] RESULT;
    always @(*) #2 RESULT = DATA1 + DATA2;   //two time unit delay is added
endmodule

module AND(DATA1, DATA2, RESULT);//Bitwise - And function - performs bitwise AND logic on DATA1 and DATA2
    input  [7:0] DATA1, DATA2;
    output reg [7:0] RESULT;
    always @(*) #1 RESULT = DATA1 & DATA2;  //one time unit delay is added
endmodule

module OR(DATA1, DATA2, RESULT);//Bitwise - Or function - performs bitwise OR logic on DATA1 and DATA2
    input  [7:0] DATA1, DATA2;
    output reg [7:0] RESULT;
    always @(*) #1 RESULT = DATA1 | DATA2;  //one time unit delay is added
endmodule

//ALU
module alu(DATA1, DATA2, SELECT, RESULT, ZERO);//8-bit Arithmetic Logic Unit (ALU)
    input  [7:0] DATA1, DATA2; //8-bit input operands
    input  [2:0] SELECT;       //3-bit selection code for ALU operations
    output reg [7:0] RESULT;   //Output for checking whether RESULT is zero or not  
    output ZERO;               //Output for checking whether RESULT is zero or not

    wire [7:0] alu_forward, alu_add, alu_and, alu_or; //Defining internal wires to connect outputs of functional units to the multiplexer
    // Instantiate functional units to calculate all operations in parallel
    FORWARD f0(DATA2, alu_forward);   //Instantiate the Forward functional unit
    ADD     f1(DATA1, DATA2, alu_add); //Instantiate the Add functional unit
    AND     f2(DATA1, DATA2, alu_and); //Instantiate the AND functional unit
    OR      f3(DATA1, DATA2, alu_or);  //Instantiate the OR functional unit

    always @(*) begin
        case (SELECT)
            3'b000 : RESULT = alu_forward; //Multiplexer select line outputs the result of the forward functional unit
            3'b001 : RESULT = alu_add;     //Multiplexer select line outputs the result of the add functional unit
            3'b010 : RESULT = alu_and;     //Multiplexer select line outputs the result of the and functional unit
            3'b011 : RESULT = alu_or;      //Multiplexer select line outputs the result of the or functional unit
            default: RESULT = 8'h00;       //Default case
        endcase
    end
    assign ZERO = (RESULT == 8'h00) ? 1'b1 : 1'b0; //Output for checking whether RESULT is zero or not
endmodule

//Register File
module reg_file(IN, OUT1, OUT2, INADDRESS, OUT1ADDRESS, OUT2ADDRESS,
                  WRITE, CLK, RESET);
    //Defining ports
    output [7:0] OUT1, OUT2; //Output ports for retrieved data
    reg    [7:0] registers [7:0]; //8x8-bit array to store registers
    input  [7:0] IN; //Input data to be written
    input  [2:0] INADDRESS, OUT1ADDRESS, OUT2ADDRESS; //Addresses for reading/writing
    input        WRITE, CLK, RESET; //Control signals

    //Asynchronous reading - two time unit delay for register reading
    //Logic retrieves data from registers identified by OUT1ADDRESS and OUT2ADDRESS instantly.
    assign #2 OUT1 = registers[OUT1ADDRESS];
    assign #2 OUT2 = registers[OUT2ADDRESS];

    always @(posedge CLK) begin
        if (RESET) begin
            registers[0] <= #1 8'h0;
            registers[1] <= #1 8'h0;
            registers[2] <= #1 8'h0;
            registers[3] <= #1 8'h0;
            registers[4] <= #1 8'h0;
            registers[5] <= #1 8'h0;
            registers[6] <= #1 8'h0;
            registers[7] <= #1 8'h0;
        end else if (WRITE == 1'b1) begin //Write enable logic - writes data to registers
            registers[INADDRESS] <= #1 IN;
        end
    end
endmodule

//CPU(cache interface version)
module cpu_cached(
    //Standard CPU ports
    input         CLK,
    input         RESET,
    output reg [31:0] PC,
    input      [31:0] INSTRUCTION, //32-bit instruction input
    //Cache / Memory interface ports (replaces internal data_memory)
    output            MEM_READ,
    output            MEM_WRITE,
    output     [7:0]  MEM_ADDRESS,    // = ALURESULT (computed address)
    output     [7:0]  MEM_WRITEDATA,  // = REGOUT1   (data to store)
    input      [7:0]  MEM_READDATA,   // data from cache on hit/fetch
    input             MEM_BUSYWAIT    // cache stalls CPU while high
);

    //Instruction field decode
    wire [7:0] OPCODE= INSTRUCTION[31:24]; //operation identifier
    wire [2:0] RD   = INSTRUCTION[18:16]; //register to write
    wire [2:0] RT   = INSTRUCTION[10:8];  //register to write
    wire [2:0] RS = INSTRUCTION[2:0];   //register to write
    wire [7:0] immediate = INSTRUCTION[7:0];   //8-bit immediate value
    wire [7:0] target_offset = INSTRUCTION[23:16]; //8-bit target offset address for 'j' and 'beq'

    //Control signals
    reg [2:0] ALUOP; // 3-bit function selector
    reg select_sub; // controls MUX 1: 0 = Choose raw REGOUT2, 1 = Choose 2's Complement
    reg select_immediate; // controls MUX 2: 0 = Choose MUX 1 output, 1 = Choose Immediate constant
    reg WRITEENABLE; // high if instruction modifies a register in the Register File

    reg branch_control; // High if current instruction is a 'beq'
    reg jump_control; // High if current instruction is an unconditional 'j'
    reg bne_control; // High if current instruction is a 'bne'

    reg mem_read_ctrl;   //internal control; drives MEM_READ port
    reg mem_write_ctrl;
    reg select_memdata; //controls the write-back MUX:

    //Datapath wires
    wire [31:0] pc_plus_4; // Sequential program execution path
    wire [31:0] branch_target_pc; // Calculated relative branch address target
    wire [31:0] pc_branch_mux_out; // Output choosing between sequential vs branch paths
    wire [31:0] pc_final_next; // Final calculated address feeding the PC register
    
    // wire [31:0] pc_next; // output of PC+4 Incrementer routed to PC input
    wire [7:0] REGOUT1; // first operand read out
    wire [7:0] REGOUT2; // second operand read out
    wire [7:0] twos_comp_out; // negative representation of REGOUT2
    wire [7:0] mux1_output; // output choosing between Addition vs Subtraction operand paths
    wire [7:0] mux2_final; // output choosing between Register vs Immediate data paths
    wire [7:0] ALURESULT; // calculated output loop bound
    wire alu_zero_flag; // wire for indicating the equal condition
    wire [7:0]  regfile_in_final; //output of the write-back MUX; feeds reg_file's IN port

    
    //Connect internal signals to output ports
    assign MEM_READ      = mem_read_ctrl;
    assign MEM_WRITE     = mem_write_ctrl;
    assign MEM_ADDRESS   = ALURESULT;   //ALU computes the effective address
    assign MEM_WRITEDATA = REGOUT1;     //data to write = first source register

    //Control logic
    always @(*) begin
        //Defaults
        WRITEENABLE = 1'b0;
        ALUOP = 3'b001;
        select_sub = 1'b0;
        select_immediate = 1'b0;
        branch_control = 1'b0;
        jump_control = 1'b0;
        bne_control = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        select_memdata = 1'b0;

        case (OPCODE)
            8'b00000000: begin WRITEENABLE = 1'b1; end                                    // add
            8'b00000001: begin WRITEENABLE = 1'b1; select_sub = 1'b1; end                // sub
            8'b00000010: begin WRITEENABLE = 1'b1; ALUOP = 3'b010; end                   // and
            8'b00000011: begin WRITEENABLE = 1'b1; ALUOP = 3'b011; end                   // or
            8'b00000100: begin WRITEENABLE = 1'b1; ALUOP = 3'b000; end                   // mov
            8'b00000101: begin WRITEENABLE = 1'b1; select_immediate = 1'b1; end          // loadi
            8'b00000110: begin jump_control = 1'b1; end                                   // j
            8'b00000111: begin branch_control = 1'b1; select_sub = 1'b1; end             // beq
            8'b00001000: begin bne_control = 1'b1; select_sub = 1'b1; end               // bne
            8'b00001001: begin                                                             // lwd
                WRITEENABLE    = 1'b1;
                ALUOP          = 3'b000;
                mem_read_ctrl  = 1'b1;
                select_memdata = 1'b1;
            end
            8'b00001010: begin                                                             // lwi
                WRITEENABLE      = 1'b1;
                ALUOP            = 3'b000;
                select_immediate = 1'b1;
                mem_read_ctrl    = 1'b1;
                select_memdata   = 1'b1;
            end
            8'b00001011: begin ALUOP = 3'b000; mem_write_ctrl = 1'b1; end               // swd
            8'b00001100: begin                                                             // swi
                ALUOP            = 3'b000;
                select_immediate = 1'b1;
                mem_write_ctrl   = 1'b1;
            end
            default: begin end
        endcase
    end

    //PC logic
    assign #1 pc_plus_4        = PC + 32'd4;
    assign #2 branch_target_pc = pc_plus_4 + ({{24{target_offset[7]}}, target_offset} << 2);
    //Equal condition routing
    //wire take_branch = branch_control & alu_zero_flag;
    wire take_branch = (branch_control & alu_zero_flag) | (bne_control & ~alu_zero_flag);
    assign pc_branch_mux_out = take_branch ? branch_target_pc : pc_plus_4;
    assign pc_final_next = jump_control ? branch_target_pc : pc_branch_mux_out;

    //Write-back mux: ALU result vs cache read data
    assign regfile_in_final = select_memdata ? MEM_READDATA : ALURESULT;

    //Register file
    reg_file processor_registers (
        .IN          (regfile_in_final),
        .OUT1        (REGOUT1),
        .OUT2        (REGOUT2),
        .INADDRESS   (RD),
        .OUT1ADDRESS (RT),
        .OUT2ADDRESS (RS),
        .WRITE       (WRITEENABLE),
        .CLK         (CLK),
        .RESET       (RESET)
    );

    //Two's complement (for sub/beq/bne)
    assign #1 twos_comp_out = ~REGOUT2 + 8'b00000001;

    //Source MUXes
    assign mux1_output = select_sub ? twos_comp_out : REGOUT2;
    assign mux2_final  = select_immediate ? immediate      : mux1_output;

    //ALU
    alu processor_alu (
        .DATA1  (REGOUT1),
        .DATA2  (mux2_final),
        .SELECT (ALUOP),
        .RESULT (ALURESULT),
        .ZERO   (alu_zero_flag)
    );

    //PC register (stalls when cache is busy)
    always @(posedge CLK) begin
        if (RESET)
            PC <= 32'h0;
        else if (!MEM_BUSYWAIT)
            PC <= pc_final_next;
        //else: hold PC while cache/memory is busy
        else begin
            PC <= PC; //hold pc value in current clk cycle when memory busy
        end
    end

endmodule
