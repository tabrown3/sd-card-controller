module fat32_controller (
    input [63:0] filename, // 8 bytes for name
    input [23:0] extension, // 3 bytes for extension
    input op_code,
    input clk,
    input [7:0] outgoing_byte,
    input btn,
    output [7:0] incoming_byte,
    output finished_byte,
    output finished_block,
    output busy,

    // pass-through (neither used nor modified at this level)
    input miso,
    output cs,
    output mosi,
    output spi_clk
);
    reg sd_op_code = 1'b0;
    reg sd_execute = 1'b0;
    reg [31:0] block_address = {32{1'b0}};
    reg [7:0] sd_outgoing_byte = 8'haa; // this is dummy data
    reg sd_btn = 1'b1;
    wire [7:0] sd_incoming_byte;
    wire sd_finished_byte;
    wire sd_finished_block;
    wire sd_busy;

    sd_card_controller SDCC0 (
        .op_code(sd_op_code),
        .execute(sd_execute),
        .clk(clk),
        .block_address(block_address),
        .miso(miso),
        .outgoing_byte(sd_outgoing_byte),
        .btn(sd_btn),
        .cs(cs),
        .incoming_byte(sd_incoming_byte),
        .mosi(mosi),
        .finished_byte(sd_finished_byte),
        .finished_block(sd_finished_block),
        .spi_clk(spi_clk),
        .busy(sd_busy)
    );
endmodule