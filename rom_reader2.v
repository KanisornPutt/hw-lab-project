`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/16/2024 11:31:16 PM
// Design Name: 
// Module Name: rom_reader2
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module rom_reader2(
    output reg [15:0] d,
    input wire [6:0] s,
    input clk
);
// declares a memory rom of 32 8-bit registers.
// (* synthesis, rom_block = "ROM_CELL XYZ01" *)
reg [15:0] rom[127:0];
// NOTE: To infer combinational logic instead of a ROM, use
// (* synthesis, logic_block *)
initial $readmemb("rom2.mem", rom);

always @(posedge clk)
begin 
    d = rom[s];
end
endmodule
