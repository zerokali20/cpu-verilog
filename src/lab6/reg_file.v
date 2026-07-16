//CO2070 - Computer Architecture
//Lab 5 - Data Memory Integration
//Group 38 -  E/22/184 (K. P. B. P. Karunanayake), E/22/353 (G. K. G. Sandeepa)

module reg_file (
    IN,           //8-bit data input  (WRITEDATA)
    OUT1,         //8-bit data output 1 (REGOUT1)
    OUT2,         //8-bit data output 2 (REGOUT2)
    INADDRESS,    //3-bit write address (WRITEREG)
    OUT1ADDRESS,  //3-bit read address 1 (READREG1)
    OUT2ADDRESS,  //3-bit read address 2 (READREG2)
    WRITE,        //Write enable (WRITEENABLE)
    CLK,          //Clock
    RESET         //Synchronous reset
);
    //Port declarations
    output [7:0] OUT1, OUT2;
    reg [7:0] registers [7:0]; //Internal register array  : 8 registers, each 8 bits wide
    input [7:0] IN;
    input [2:0] INADDRESS, OUT1ADDRESS, OUT2ADDRESS;
    input WRITE, CLK, RESET; 

    //READ  (asynchronous)
    //Outputs update immediately whenever address or register
    //no clock edge needed.
    //Artificial delay of #2 for read
    assign #2 OUT1 = registers[OUT1ADDRESS]; 
    assign #2 OUT2 = registers[OUT2ADDRESS];

    always @(posedge CLK) 
    begin
        if (RESET == 1'b1) begin
            registers[0] <= #1 8'h0;    //Synchronous reset: clear all registers
            registers[1] <= #1 8'h0;
            registers[2] <= #1 8'h0;
            registers[3] <= #1 8'h0;
            registers[4] <= #1 8'h0;
            registers[5] <= #1 8'h0;
            registers[6] <= #1 8'h0;
            registers[7] <= #1 8'h0;
        end
        else if (WRITE == 1'b1) begin //Synchronous write on rising clock edge
            registers[INADDRESS] <= #1 IN;
        end
    end
endmodule



