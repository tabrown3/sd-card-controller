`timescale 1us/100ns
module tb_spi_controller();
    reg execute = 1'b0;
    reg clk = 1'b0;
    reg miso = 1'b1;
    reg [7:0] out_word = 8'h00;
    wire spi_clk;
    wire mosi;
    wire [7:0] in_word;
    wire finished;

    spi_controller SPI_CONT(
        .execute(execute),
        .clk(clk),
        .miso(miso),
        .out_word(out_word),
        .spi_clk(spi_clk),
        .mosi(mosi),
        .in_word(in_word),
        .finished(finished)
    );

    initial begin
        #10;
        out_word = 8'ha6;
        execute = 1'b1;
        #1;
        execute = 1'b0;
        #20;
        $stop;
    end

    always begin
        #0.5;
        clk = ~clk;
        #0.5;
        clk = ~clk;
    end
endmodule