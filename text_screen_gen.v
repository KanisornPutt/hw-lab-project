`timescale 1ns / 1ps

module text_screen_gen(
    input clk, reset,
    input video_on,
    input set,
    input [7:0] data_in,
    input [9:0] x, y,
    input wire [2:0] theme_sel,
    output reg [11:0] rgb
);
    
    // signal declaration
    wire [6:0] sw;
    wire lang_w, lang_r;
    assign {lang_w, sw} = data_in;
    
    wire newline = (data_in[6:0] == 7'd13); 
    wire backspace = (data_in[6:0] == 7'd92); 
    wire reset_btn = ((data_in[6:0] == 7'd127) || (data_in[6:0] == 7'd47)); 
    
    // ascii ROM
    wire [10:0] rom_addr;
    wire [6:0] char_addr;
    wire [3:0] row_addr;
    wire [2:0] bit_addr;
    wire [7:0] font_word;
    wire [7:0] font_word_std;
    wire [7:0] font_word_th;
    wire ascii_bit;
    
    // tile RAM
    wire we;                    // write enable
    wire [11:0] addr_r, addr_w;
    wire [7:0] din, dout;
    
    // 80-by-30 tile map
    parameter MAX_X = 80;   // 640 pixels / 8 data bits = 80
    parameter MAX_Y = 30;   // 480 pixels / 16 data rows = 30
    
    // cursor
    reg [6:0] cur_x_reg;
    reg [6:0] cur_x_next;
    reg [4:0] cur_y_reg;
    reg [4:0] cur_y_next;
    wire cursor_on, set_db;
    assign we = set_db;
    
    // delayed pixel count
    reg [9:0] pix_x1_reg, pix_y1_reg;
    reg [9:0] pix_x2_reg, pix_y2_reg;
    
    // object output signals
    wire [11:0] text_rgb, text_rev_rgb;
    
    // body
    // instantiate debounce for four buttons
    assign set_db = set;

    // instantiate the ascii / font rom
    ascii_rom a_rom(.clk(clk), .addr(rom_addr), .data(font_word_std));
    ascii_rom_th a_rom_th(.clk(clk), .addr(rom_addr), .data(font_word_th));
    assign font_word = lang_r ? font_word_th : font_word_std;
    // assign font_word = font_word_std;
    // instantiate dual-port video RAM (2^12-by-7)
    dual_port_ram dp_ram(.clk(clk), .reset(reset), .we(set), .addr_a(addr_w), .addr_b(addr_r),
                         .din_a(din), .dout_a(), .dout_b(dout));
    
    // registers
    always @(posedge clk or posedge reset)
        if(reset) begin
            cur_x_reg <= 0;
            cur_y_reg <= 0;
            pix_x1_reg <= 0;
            pix_x2_reg <= 0;
            pix_y1_reg <= 0;
            pix_y2_reg <= 0;
        end    
        else if (we) begin
            cur_x_reg <= cur_x_next;
            cur_y_reg <= cur_y_next;
            pix_x1_reg <= x;
            pix_x2_reg <= pix_x1_reg;
            pix_y1_reg <= y;
            pix_y2_reg <= pix_y1_reg;
        end
    
    /* tile RAM write */
    assign addr_w = {cur_y_reg, cur_x_reg};
    assign din = {lang_w, sw};
    
    /* tile RAM read */
    // use nondelayed coordinates to form tile RAM address
    assign addr_r = {y[8:4], x[9:3]};
    assign {lang_r, char_addr} = dout;
    
    // font ROM
    assign row_addr = y[3:0];
    assign rom_addr = {char_addr, row_addr};
    
    // use delayed coordinate to select a bit
    assign bit_addr = pix_x2_reg[2:0];
    assign ascii_bit = font_word[~bit_addr];
    
    /* cursor x position */
    always @ (posedge set) begin
    case (1'b1)
        // Logic for cur_x_next
        (backspace && cur_x_reg == 0 && cur_y_reg == 0): 
            cur_x_next = 0;
        backspace && cur_x_reg == 0: 
            cur_x_next = MAX_X - 1;
        backspace: 
            cur_x_next = cur_x_reg - 1;
        ((set_db && (cur_x_reg == MAX_X - 1)) || reset_btn || newline): 
            cur_x_next = 0; // Reset to 0 if bounds are reached
        set_db: 
            cur_x_next = cur_x_reg + 1; // Move right
        default: 
            cur_x_next = cur_x_reg; // No move
    endcase
    end
    
    /* cursor y position */
    always @ (posedge set) begin
        case (1'b1)
            // Logic for cur_y_next
            (backspace && cur_x_reg == 0 && cur_y_reg == 0):
                cur_y_next = 0;
            (backspace && cur_x_reg == 0):
                cur_y_next = cur_y_reg - 1;
            backspace: 
                cur_y_next = cur_y_reg; // No move
            (((set_db && (cur_x_reg == MAX_X - 1)) || (newline)) && (cur_y_reg == MAX_Y - 1)) || reset_btn: 
                cur_y_next = 0; // Reset to 0 if bounds are reached
            ((set_db) && (cur_x_reg == MAX_X - 1) || newline): 
                cur_y_next = cur_y_reg + 1; // Move down   
            default: 
            
                cur_y_next = cur_y_reg; // No move
        endcase
    end
    
    wire [2:0] hex_r, hex_g, hex_b;
    
    assign hex_r = theme_sel[2] ? 4'hf : 4'd0;  
    assign hex_g = theme_sel[1] ? 4'hf : 4'd0;
    assign hex_b = theme_sel[0] ? 4'hf : 4'd0;              
         
    wire [11:0] text_color;
    assign text_color = {hex_r, hex_g, hex_b};
    
    wire [11:0] bg_color;
    assign bg_color = {~hex_r, ~hex_g, ~hex_b};
    
    // object signals
    // green over black and reversed video for cursor
    assign text_rgb = (ascii_bit) ? text_color : bg_color ;
    assign text_rev_rgb = (ascii_bit) ? bg_color : text_color;
    
    // use delayed coordinates for comparison
    assign cursor_on = (pix_y2_reg[8:4] == cur_y_reg) &&
                       (pix_x2_reg[9:3] == cur_x_reg);
                       
    // rgb multiplexing circuit
    always @*
        if(~video_on)
            rgb = bg_color;     // blank
        else
            if(cursor_on)
                rgb = text_rev_rgb;
            else
                rgb = text_rgb;
      
endmodule