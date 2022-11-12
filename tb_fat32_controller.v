module tb_fat32_controller ();
    reg [63:0] filename = {
        8'd114, // r
        8'd111, // o
        8'd109, // m
        {5{8'd32}} // SPACE x5
    };
    reg [23:0] extension = {
        8'd98, // b
        8'd105, // i
        8'd110 // n
    };
    integer file_size = 100; // bytes
    reg op_code = 1'b0;
    reg execute = 1'b0;
    reg clk = 1'b0;
    reg [7:0] outgoing_byte = 8'h00;
    wire [7:0] incoming_byte;
    wire finished_byte;
    wire finished_block;
    wire busy;

    reg miso = 1'b0;
    wire cs;
    wire mosi;
    wire spi_clk;

    fat32_controller F32C0 (
        .filename(filename),
        .extension(extension),
        .file_size(file_size),
        .op_code(op_code),
        .execute(execute),
        .clk(clk),
        .outgoing_byte(outgoing_byte),
        .incoming_byte(incoming_byte),
        .finished_byte(finished_byte),
        .finished_block(finished_block),
        .busy(busy),

        .miso(miso),
        .cs(cs),
        .mosi(mosi),
        .spi_clk(spi_clk)
    );
endmodule