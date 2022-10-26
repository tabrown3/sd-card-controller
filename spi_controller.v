module spi_controller
#(
    parameter [3:0] FRAME_WIDTH = 4'h8
)(
    input execute,
    input clk,
    input miso,
    input [FRAME_WIDTH-1'b1:0] out_word,
    output spi_clk,
    output reg mosi = 1'b1,
    output reg [FRAME_WIDTH-1'b1:0] in_word = 8'hff,
    output reg finished = 1'b0,
    output busy
);
    reg executing = 1'b0;
    reg [3:0] cur_bit = 4'h0;

    assign spi_clk = executing ? clk : 1'b0;
    assign busy = executing;
    always @(negedge clk) begin
        if (finished) begin
            finished <= 1'b0;
        end

        if (!executing) begin
            if (execute) begin
                executing <= 1'b1;
                mosi <= out_word[FRAME_WIDTH - 1'b1 - cur_bit];
            end
        end else begin
            if (cur_bit < FRAME_WIDTH) begin
                mosi <= out_word[FRAME_WIDTH - 1'b1 - cur_bit];
            end else begin
                executing <= 1'b0;
                finished <= 1'b1;
            end
        end
    end
    
    always @(posedge clk) begin
        if (executing) begin
            in_word[FRAME_WIDTH - 1'b1 - cur_bit] <= miso;
            cur_bit <= cur_bit + 4'h1;
        end else begin
            cur_bit <= 4'h0;
        end
    end
endmodule