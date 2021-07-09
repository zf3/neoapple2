`timescale 1ns / 1ps

module Z1_TOP_testbench(

    );

// Highest frequency is 257.7273 Mhz, cycle T = 3.880071 ns, signal change at half of that, i.e. t = 1.940036

reg CLK_64M;    // 4t
reg CLK_28M;    // 9t
reg CLK_14M;    // 18t

reg image_clk = 0;
reg image_start = 0;
reg [7:0] image_data = 0;

Z1_TOP UUT (.CLK_64M(CLK_64M), .CLK_28M(CLK_28M), .CLK_14M(CLK_14M), .image_clk(image_clk), .image_start(image_start), .image_data(image_data));


initial begin 
    CLK_64M = 0;
    CLK_28M = 0;
    CLK_14M = 0;
    forever begin
        #1.940036;
        #1.940036;
        #1.940036;
        #1.940036;
        CLK_64M = ~CLK_64M; // 4t
        #1.940036;
        #1.940036;
        #1.940036;
        #1.940036;
        CLK_64M = ~CLK_64M; // 8t
        #1.940036;
        CLK_28M = ~CLK_28M; // 9t
        #1.940036;
        #1.940036;
        #1.940036;
        CLK_64M = ~CLK_64M; // 12t
        #1.940036;
        #1.940036;
        #1.940036;
        #1.940036;
        CLK_64M = ~CLK_64M; // 16t
        #1.940036;
        #1.940036;
        CLK_14M = ~CLK_14M; // 18t
        CLK_28M = ~CLK_28M; 
        #1.940036;
        #1.940036;
        CLK_64M = ~CLK_64M; // 20t
        #1.940036;
        #1.940036;
        #1.940036;
        #1.940036;
        CLK_64M = ~CLK_64M; // 24t
        #1.940036;
        #1.940036;
        #1.940036;
        CLK_28M = ~CLK_28M; // 27t 
        #1.940036;
        CLK_64M = ~CLK_64M; // 28t
        #1.940036;
        #1.940036;
        #1.940036;
        #1.940036;
        CLK_64M = ~CLK_64M; // 32t
        #1.940036;
        #1.940036;
        #1.940036;
        #1.940036;
        CLK_64M = ~CLK_64M; // 36t
        CLK_28M = ~CLK_28M;
        CLK_14M = ~CLK_14M;        
    end
end    

reg [7:0] track;
reg [17:0] i;

// Test disk image receiver
initial begin
    // Start cycle
    #500;
    image_clk = 1;
    image_start = 1;
    #500;
    image_clk = 0;
    image_start = 0;
    
    // Data transfer
    for (track = 0; track < 35; track = track + 1) 
        for (i = 0; i < 6656; i = i + 1) begin
            #500;
            image_clk = 1;
            image_data = (track + i) % 256;
            #500;
            image_clk = 0;    
        end;
    
    // Stop cycle
    #500;
    image_clk = 1;
    image_data = 0;
    #500;
    image_clk = 0;
    
end

endmodule
