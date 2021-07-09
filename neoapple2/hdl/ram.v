
module ram #(parameter
    ADDR_WIDTH = 16,
    DATA_WIDTH = 8,
    DEPTH = 1024*48)
(
    input wire clk,
    input wire cs,
    input wire [ADDR_WIDTH-1:0] addr, 
    input wire we,
    input wire [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out 
);

reg [DATA_WIDTH-1:0] memory_array [0:DEPTH-1]; 

reg [16:0] k;
initial begin
    for (k = 0; k < DEPTH; k = k+1) begin
        memory_array[k] = 0;
    end
end

always @(posedge clk) begin
    if (cs) begin
        if (we) begin
            memory_array[addr] <= data_in;
        end
        data_out <= memory_array[addr];
    end
end

endmodule
