/*
Module  : 256x8-bit data memory 
Author  : Isuru Nawinne, Kisaru Liyanage
Date    : 25/05/2020

Description	:

This file presents a primitive data memory module for CO2070 Lab 5
This memory allows data to be read and written as 1-Byte words
*/

`timescale 1ns/100ps

module dmem (
    input mem_clock,
    input [5:0] mem_address,  //Block address(0–63)
    input [31:0] mem_writedata,  //32-bit block to write (cache → memory)
    output reg [31:0] mem_readdata,  //32-bit block read back (memory → cache)
    input mem_read,     //Read request from cache
    input mem_write,    //Write request from cache
    output reg mem_busywait   //High while memory is processing a request
);

    //64-block × 32-bit storage array
    reg [31:0] mem_array [0:63];

    //Internal state
    integer wait_cycles;        //Counts down from 19 to 0 (20 cycles total)
    reg     operation_pending;  //High while a read/write is in progress
    reg     pending_read;       //Latches which operation is in flight

    //Memory initialisation
    integer i;
    initial begin
        mem_busywait = 1'b0;
        mem_readdata = 32'h0;
        wait_cycles  = 0;
        operation_pending = 1'b0;
        pending_read = 1'b0;

        //Pre-load each block with its own byte addresses.
        //Block j: byte[offset=0]=j*4, byte[offset=1]=j*4+1, ...
        //Stored little-endian: bits[7:0]=byte0, bits[31:24]=byte3.
        begin : init_mem
            integer j;
            reg [7:0] b0, b1, b2, b3;
            for (j = 0; j < 64; j = j + 1) begin
                b0 = j * 4;     //offset-0 byte value
                b1 = j * 4 + 1;   //offset-1 byte value
                b2 = j * 4 + 2;  //offset-2 byte value
                b3 = j * 4 + 3;    //offset-3 byte value
                mem_array[j] = {b3, b2, b1, b0};
            end
        end
    end

    //Registered copy of busywait (for edge detection)    
    //Prevents a second operation from being accidentally triggered
    //by the combinational glitch on mem_read/mem_write that occurs
    //when the cache FSM moves from MEM_READ back to IDLE on the
    //same edge that the memory de-asserts mem_busywait.
    reg prev_busywait;

    //Rising-edge access logic
    always @(posedge mem_clock) begin
        prev_busywait <= mem_busywait;  //track previous cycle's state

        if (!operation_pending) begin
            //Accept a new request only when we were genuinely idle
            //(prev_busywait=0) AND a request is presented now.
            if ((mem_read || mem_write) && !prev_busywait) begin
                mem_busywait      <= #1 1'b1;  //stall the cache
                operation_pending <= 1'b1;
                pending_read      <= mem_read;
                wait_cycles       <= 19;   //20 cycles: 19 wait + 0 → done
            end
        end else begin
            //Count down 20 cycles
            if (wait_cycles > 0) begin
                wait_cycles <= wait_cycles - 1;
            end else begin
                //Access complete: perform the operation
                if (pending_read) begin
                    //Read:deliver the block to the cache
                    #1 mem_readdata = mem_array[mem_address];
                end else begin
                    //Write:commit the dirty block from the cache
                    mem_array[mem_address] <= #1 mem_writedata;
                end
                //De-assert busy and clear state
                mem_busywait      <= #1 1'b0;
                operation_pending <= 1'b0;
                pending_read      <= 1'b0;
            end
        end
    end

endmodule