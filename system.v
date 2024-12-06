`timescale 1ns / 1ps

module system(
    input clk,              // 100MHz Basys 3
    input reset,            // sw[15]
    input btnC,             // set
    input btnU,             // up
    input btnD,             // down
    input btnL,             // left
    input btnR,             // right
    input [7:0] sw,         // sw[6:0] sets ASCII value
    input wire RsRx,        // UART Recieve
    output wire RsTx,       // UART Transmit
    output [3:0] an,        // display enable
    output hsync, vsync,    // VGA connector
    output [11:0] rgb,      // DAC, VGA connector
    output [6:0] seg,       // Seven Segment Display  
    output dp,              // Decimal point
        
    // uart from another board 
    input  JA0,          // Receive from another board
    output JA1         // Transmit to another board
    );
    
    // signals
    wire [9:0] w_x, w_y;
    wire w_vid_on, w_p_tick;
    reg [11:0] rgb_reg;
    wire [11:0] rgb_next;
    
    wire [3:0] num3, num2, num1, num0; // left to right
    wire [15:0] d;
    wire an0, an1, an2, an3;
    assign an = {an3, an2, an1, an0};
    
    
    //UART
    wire [7:0] data_in, data_out; //WRITE DATA FROM UART, DATA THAT SHOWN ON SCREEN
    wire transmit1, transmit2;
    wire receive1, receive2;
    wire gnd; // ground
    wire [7:0] gnd_b; // ground bus
    
    // Clock
    wire targetClk;
    wire [18:0] tclk;
    
    assign {num3, num2, num1, num0} = d;
    assign tclk[0] = clk;
    
    genvar c;
    generate for (c = 0; c < 18; c = c + 1) begin
        clockDiv fDiv(tclk[c+1], tclk[c]);
    end endgenerate
    
    clockDiv fdivTarget(targetClk, tclk[18]);
    
    
 
    // Display
    quadSevenSeg q7seg(seg, dp, an0, an1, an2, an3, num0, num1, num2, num3, targetClk);    
    
    // Directly connect outputs of rom_reader2 to num0 and num1
    rom_reader2 rr2(d, sw, targetClk);
    
    // instantiate vga controller
    vga_controller vga(.clk_100MHz(clk), .reset(reset), .video_on(w_vid_on),
                       .hsync(hsync), .vsync(vsync), .p_tick(w_p_tick), 
                       .x(w_x), .y(w_y));
    
    // instantiate text generation circuit
    text_screen_gen tsg(.clk(clk), .reset(reset), .video_on(w_vid_on), .set(btnC),
                        .up(btnU), .down(btnD), .left(btnL), .right(btnR),
                        .sw(data_in[6:0]), .x(w_x), .y(w_y), .rgb(rgb_next));
                        
    // UART1 Receive from another and transmit to monitor
    uart uart1(.tx(RsTx), .data_transmit(gnd_b),
               .rx(JA0), .data_received(data_in), .received(received1),
               .dte(1'b0), .clk(clk));
                
    // UART2 Receive from keyboard or switch and transmit to another
    uart uart2(.rx(RsRx), .data_transmit(sw[7:0]), 
               .tx(JA1), .data_received(gnd_b), .received(received2),
               .dte(btnU), .clk(clk));
    
    // rgb buffer
    always @(posedge clk) begin
        if(w_p_tick)
            rgb_reg <= rgb_next;
    end
          
    // output
    assign rgb = rgb_reg;
    
endmodule