`timescale 1us/100ns
module tb_sd_card_controller();

    reg op_code = 1'b0;
    reg execute = 1'b0;
    reg clk = 1'b1;
    reg [31:0] block_address = {32{1'b0}};
    reg miso = 1'b0;
    reg [7:0] outgoing_byte = 8'haa;
    reg btn = 1'b1;
    integer clk_cnt = 0;
    wire cs;
    wire [7:0] incoming_byte;
    wire mosi;
    wire finished_byte;
    wire finished_block;
    wire spi_clk;
    wire busy;

    sd_card_controller SDCC0 (
        .op_code(op_code),
        .execute(execute),
        .clk(clk),
        .block_address(block_address),
        .miso(miso),
        .outgoing_byte(outgoing_byte),
        .btn(btn),
        .cs(cs),
        .incoming_byte(incoming_byte),
        .mosi(mosi),
        .finished_byte(finished_byte),
        .finished_block(finished_block),
        .spi_clk(spi_clk),
        .busy(busy)
    );

    initial begin
        #50;
        btn = 1'b0;
        #20000;
        $stop;
    end

    always begin
        #0.5;
        clk = ~clk;
        #0.5;
        clk = ~clk;
    end

    always @(negedge clk) begin
        if (clk_cnt > 4450 && clk_cnt < 4920) begin
            miso <= 1'b0;
        end else if (clk_cnt > 6795 && clk_cnt < 6803) begin
            miso <= 1'b1;
        end else begin
            miso <= $random;
        end

        if (clk_cnt == 5870) begin
            execute <= 1'b1;
        end else if (clk_cnt == 11850) begin
            execute <= 1'b1;
            op_code <= 1'b1;
        end else begin
            execute <= 1'b0;
        end

        clk_cnt <= clk_cnt + 1;
    end
endmodule