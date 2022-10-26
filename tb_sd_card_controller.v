`timescale 1us/100ns
module tb_sd_card_controller();

    reg op_code = 1'b0;
    reg execute = 1'b0;
    reg clk = 1'b1;
    reg [25:0] sector_address = {26{1'b0}};
    reg miso = 1'b0;
    reg [7:0] outgoing_byte = 8'h00;
    wire cs;
    wire [7:0] incoming_byte;
    wire mosi;
    wire finished_byte;
    wire finished_sector;
    wire spi_clk;
    wire busy;

    sd_card_controller SDCC0 (
        .op_code(op_code),
        .execute(execute),
        .clk(clk),
        .sector_address(sector_address),
        .miso(miso),
        .outgoing_byte(outgoing_byte),
        .cs(cs),
        .incoming_byte(incoming_byte),
        .mosi(mosi),
        .finished_byte(finished_byte),
        .finished_sector(finished_sector),
        .spi_clk(spi_clk),
        .busy(busy)
    );

    initial begin
        #1000;
        $stop;
    end

    always begin
        #0.5;
        clk = ~clk;
        #0.5;
        clk = ~clk;
    end
endmodule