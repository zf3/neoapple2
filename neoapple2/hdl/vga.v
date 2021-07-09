// Line-Tripler for Apple 2 Video
// Feng Zhou, 2021-6
//
// Resolution is expanded from 280x192 to 840x576. Pixel clock becomes 64.4Mhz, so that it satisfies 
// rgb2dvi's minimal pixel clock requirement of at least 40Mhz.
//
// This is a rewrite of apple2fpga's vga_controller.vhdl. The basic ideas is to make sure 
// horizontal refresh rate is a multiple of NTSC's 15.72Khz (actually 3 times). This way we only need 
// to buffer 2 lines instead of the whole frame (to avoid overflow/underflow otherwise). We can them 
// work from there towards our timings,
//  
//   * 1 line becomes 3, then vertical resolution: 262*3 = 786
//   * 1 pixel becomes 9 pixels, therefore pixel clock is 7.15909 * 9 = 64.43181 Mhz
//   * Horizontal refresh rate is 15.72*3 = 47.16 Khz
//   * Total horizontal pixels, including blank, is (1000/47.16)/(1/64.43181) = 1366
//   * Active resolution: 840x573
//   * Apple II's total horizontal pixels: 1/15.27k / (1/7.159091M) = 469
//   * Frequencies: NTSC colorburst = 315/88 = 3.579545, 2x = 7.159091 (Apple2 pixel clock), 
//                 4x = 14.318182 (Apple2 video signal bitrate), 8x = 28.636364, 
//                 18x = 64.431818 (new pixel clock)
//
//  Our final timing table (note that only "active" and "total" are fixed, the other 3 columns are arbitrary, 
//  as long as they make the correct "total" number)
//
//    |   | Active | Front Porch | Sync | Back Porch | Total
//    |---|--------|-------------|------|------------|-------
//    | H |  840   |     100     |  200 |     226    |  1366
//    | V |  573   |      50     |  100 |     63     |  786

`timescale 1 ns / 10 ps

module vga #
(
    // 3xApple2: 840*573, pixel clock = 64.43181
	parameter H_ACTIVE = 840,
	parameter H_FRONT_PORCH = 100,
	parameter H_SYNC = 200,
	parameter H_BACK_PORCH = 228,      // instead of 226, to account for the 2 extra clock cycles of the apple 2 clock per scanline
	parameter V_ACTIVE = 576,
	parameter V_FRONT_PORCH = 50,
	parameter V_SYNC = 100,
	parameter V_BACK_PORCH = 63	
)
(
	input wire clk,    // 64Mhz pixel clock
	input wire resetn,
	input wire VIDEO,
	input wire HBL,
	input wire VBL,
	input wire COLOR_LINE,
	
	output reg [23:0] vid_data,
	output reg vid_hsync,
	output reg vid_vsync,
	output wire vid_vde,
	
	input wire [31:0] fake_leds,
	input wire fake_leds_on
);

localparam H_TOTAL = H_ACTIVE + H_FRONT_PORCH + H_SYNC + H_BACK_PORCH;
localparam V_TOTAL = V_ACTIVE + V_FRONT_PORCH + V_SYNC + V_BACK_PORCH;
localparam POS_MAX = H_TOTAL * 3;
localparam LINE_MAX = 280;

reg [12:0] pos;
reg [9:0] y0;       // if you change '9', then change 1024 in "y0 <= 1024 - 3" below. we need it to wrap around
reg idle = 1;
reg hbl_delayed;
reg vbl_delayed;
reg video_delayed;
reg pre_vid_vde;

wire [10:0] x = pos % H_TOTAL;
wire [9:0] y = pos / H_TOTAL + y0;
wire [12:0] nextpos = idle ? 0 : (pos < POS_MAX - 1 ? pos + 1 : POS_MAX - 1);

// double line buffer (560 14Mhz pixels per line)
// highest-bit choses even or odd line
reg line [0:2047];

// the current line to write to; ~writeline is the line to read from.
reg writeline = 0;
wire [9:0] ww = pos * 2 / 9;
wire [10:0] ram_write_addr = {writeline, ww};
wire ram_we = !idle & (pos % 9 == 0 || pos % 9 == 5);
wire [9:0] vx = x / 3;
wire [9:0] xaddr = x * 2 / 3;
wire [10:0] ram_read_addr = {~writeline, xaddr}; 
reg [7:0] ram_data_out;     // RAM has 1-cycle delay

assign vid_vde = !idle && x >= 27 && x < H_ACTIVE + 27 && y >= 3 && y < V_ACTIVE + 3;

// Color decoding
reg [5:0] shift_reg;  // last 6 VIDEO pixels, to generate color, see: http://www1.cs.columbia.edu/~sedwards/papers/edwards2009retrocomputing.pdf 
reg [7:0] basis_r [3:0];    // Only SystemVerilog can do localparam arrays... 
reg [7:0] basis_g [3:0];
reg [7:0] basis_b [3:0];
initial begin
    basis_r[0] <= 8'h88;    basis_r[1] <= 8'h38;    basis_r[2] <= 8'h07;    basis_r[3] <= 8'h38;
    basis_g[0] <= 8'h22;    basis_g[1] <= 8'h24;    basis_g[2] <= 8'h67;    basis_g[3] <= 8'h52;
    basis_b[0] <= 8'h2C;    basis_b[1] <= 8'hA0;    basis_b[2] <= 8'h2C;    basis_b[3] <= 8'h07;
end

// Total On-Screen-Display width 10 * (32 + 3) = 350, height is 5
// With the area we display 32 5x5 "LEDs"', grouped by 8.
// 1. IF (x % 10 >= 5) || (x / 10 % 9 == 8) THEN OFF
// 2. Otherwise, result is fake_leds[31 - ((x/10)/9*8 + (x/10)%9)]
wire [1:0] led_osd;     // 0: transparent, 1: dark-red (for '0'), 2: bright-red (for '1') 
assign led_osd =     (y >= 10 || x >= 350)   ?   0 : 
                     ((x % 10 >= 5 || x / 10 % 9 == 8)   ?   0 :
                       (fake_leds[31 - x/10/9*8 - x/10%9] ? 2 : 1 ));

integer i;
initial begin
    for (i = 0; i < 1024; i=i+1) begin
        line[i] = 0;
    end
end

reg [7:0] r;
reg [7:0] g;
reg [7:0] b;

always @(posedge clk) begin
	if (!resetn) begin
        y0 <= 0;
        pos <= 0;
        idle <= 1;        
	end else begin
	    if (!VBL && vbl_delayed) begin
	        // start of new frame
            y0 <= 1024 - 3;
	    end else if (!HBL && hbl_delayed) begin
            // start of new line
            idle <= 0;
            pos <= 0;
            y0 <= y0 + 3;
            writeline <= ~writeline;    // flip writeline
        end else if (!idle) begin
            if (pos == POS_MAX - 1)
                idle <= 1;
            pos <= nextpos;
        end
        hbl_delayed <= HBL;
        vbl_delayed <= VBL;
        video_delayed <= VIDEO;
        
        r = 0; g = 0; b = 0; 
        if (!COLOR_LINE) begin
            // Monochrome
            if (shift_reg[2]) begin
                r = 8'hff; g = 8'hff; b = 8'hff; 
            end
        end else if (shift_reg[0] == shift_reg[4] && shift_reg[5] == shift_reg[1]) begin
            // Tint of adjacent pixels is consistent : display the color
            if (shift_reg[1]) begin
                r = r + basis_r[vx * 2];
                g = g + basis_g[vx * 2];
                b = b + basis_b[vx * 2];
            end
            if (shift_reg[2]) begin
                r = r + basis_r[vx * 2 + 1];
                g = g + basis_g[vx * 2 + 1];
                b = b + basis_b[vx * 2 + 1];
            end;
            if (shift_reg[3]) begin
                r = r + basis_r[vx * 2 + 2];
                g = g + basis_g[vx * 2 + 2];
                b = b + basis_b[vx * 2 + 2];
            end;
            if (shift_reg[4]) begin
                r = r + basis_r[vx * 2 + 3];
                g = g + basis_g[vx * 2 + 3];
                b = b + basis_b[vx * 2 + 3];
            end;
        end else begin
            // Tint is changing: display only black, gray, or white
            case (shift_reg[3:2])
                2'b11: begin
                        r = 8'hFF; g = 8'hFF; b = 8'hFF;
                    end
                2'b01, 2'b10: begin
                        r = 8'h80; g = 8'h80; b = 8'h80;
                    end
                default: begin
                        r = 0; g = 0; b = 0;
                    end
            endcase;        
        end
//        vid_data[7:0] <= (nextx < H_ACTIVE && nexty < V_ACTIVE) ? nextx : 0;
//        vid_data[7:0] <= (x < H_ACTIVE && y < V_ACTIVE) ? x + y : 0;
        vid_data <= (fake_leds_on == 0 || led_osd == 0) ?
                        (x/3 < LINE_MAX + 9 ? {r,b,g} : 0) :
                        (led_osd == 1 ? 24'h400000 : 24'hff0000 );
        vid_hsync <= (x >= H_ACTIVE + H_FRONT_PORCH) && (x < H_ACTIVE + H_FRONT_PORCH + H_SYNC);
        vid_vsync <= (y >= V_ACTIVE + V_FRONT_PORCH) && (y < V_ACTIVE + V_FRONT_PORCH + V_SYNC);
	end
end

reg shift_reg_buf;

always @(posedge clk) begin
    if (ram_we) begin
        line[ram_write_addr] <= video_delayed;
    end
    ram_data_out <= line[ram_read_addr];
    if (x % 3 == 1)
        shift_reg_buf <= line[ram_read_addr];
    if (x % 3 == 2)   // Two video bits consumed every hires pixel
        shift_reg <= {line[ram_read_addr], shift_reg_buf, shift_reg[5:2]}; 
end

endmodule
