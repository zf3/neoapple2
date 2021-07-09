// PWM audio output for Apple II
// Feng Zhou, 2021-7

module audio_pwm (
    input wire clk,     // 14 Mhz
    input wire [7:0] audio,    // Sampling frequency is 14 Mhz / 256, valid range is [1,255]
    
    output reg aud_pwm,
    output wire aud_sd
);

reg [7:0] counter = 0;
reg [7:0] audio_latched = 0;
assign aud_sd = 1;

always @(posedge clk) begin
    if (counter == 0)
        audio_latched <= audio;
    if (counter < 1 || (counter < audio_latched && counter < 255) )
        aud_pwm <= 1;
    else
        aud_pwm <= 0;
    counter <= counter + 1;
end

endmodule