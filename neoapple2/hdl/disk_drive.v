
// Disk II emulator
// Feng Zhou, 2021-7

module disk_drive (
    input wire CLK_14M,
    input wire [5:0] track,
    output reg [13:0] ram_write_addr,
    output reg [7:0] ram_do,
    output reg ram_we = 0,
    
    // image loading interface
    input wire image_clk,       // one byte on every posedge @ 1 MBps
    input wire image_start,     // when this go high, we start an image transfer
    input wire [7:0] image_data, // actual image data
    
    output wire debug_loading,
    output wire [17:0] debug_loading_pos
    );

// 35 track * 6656 = 232,960 bytes
localparam IMAGE_MAX = 232960;

reg [7:0] image [0:IMAGE_MAX-1];
reg [12:0] pos;
reg [5:0] mytrack = 63;
reg idle = 1;
reg image_changed = 0;

localparam LOADING_IDLE = 0;
localparam LOADING_RUNNING = 1;
localparam LOADING_DONE = 2;

// FPGA clock domain
reg [17:0] loading_pos = 0;
reg loading_byte_ready2 = 0;
reg loading_byte_ready3 = 0;
reg loading_start2 = 0;
reg loading_start3 = 0;

// image_clk domain
reg loading_image_ready = 0;
reg loading_byte_received = 0;
wire loading_byte_ready = loading_byte_received & image_clk;
reg [7:0] loading_byte;
reg [17:0] loading_count;

assign debug_loading = loading_image_ready;
assign debug_loading_pos = loading_pos;

initial begin
    $readmemh("d:/Work/FPGA/rtl-toys/neoapple2/hdl/dos3.3.1983.nib.hex", image);
end

// Data loading from PS CPU
// image_clk is a clock of at most 1 Mhz
// Sequence: 1. image_clk becomes available, 2. One start cycle (image_start == 1), 3. Transmission of IMAGE_MAX bytes, 4. End of image_clk
always @(posedge image_clk) begin
    if (image_start) begin
        // posedge of image_clk 
        // start loading from PS
        loading_count <= 0;
    end else begin
        // continue loading, 1 byte per image_clk cycle
        if (loading_count < IMAGE_MAX) begin
            loading_byte <= image_data;
            loading_byte_received <= 1;
            loading_count <= loading_count + 1;
        end else
            loading_byte_received <= 0;
    end
end

// Cross to FPGA clock domain
always @(posedge CLK_14M) begin
    loading_byte_ready2 <= loading_byte_ready;
    loading_byte_ready3 <= loading_byte_ready2;
    loading_start2 <= image_start;
    loading_start3 <= loading_start2;
    if (loading_start2 && !loading_start3) begin
        loading_pos <= 0;
    end else if (loading_byte_ready2 && !loading_byte_ready3) begin
        if (loading_pos < IMAGE_MAX)
            image[loading_pos] <= loading_byte;
        if (loading_pos == IMAGE_MAX - 1)   // One cycle of positive
            loading_image_ready <= 1;
        loading_pos <= loading_pos + 1;    
    end else begin
        loading_image_ready <= 0;
    end
end

// Send track data to 6502 upon request
always @(posedge CLK_14M) begin
    if (loading_image_ready) begin
        image_changed <= 1; // turn the pulse of loading_image_ready into a state
    end else if (idle && (track != mytrack || image_changed)) begin
        // start reading of a track, or we just finished loading from PS CPU
        pos <= 0;
        idle <= 0;    
        mytrack <= track;
        image_changed <= 0;
    end if (!idle) begin
        if (pos < 6656) begin
            // Transfer a byte 
            ram_write_addr <= pos;
            ram_do <= image[pos + mytrack * 6656];
            ram_we <= 1; 
            pos <= pos + 1;
        end else begin
            // End of transfer
            idle <= 1;
            ram_we <= 0;        
        end
    end    
end    

endmodule