module sd_card_controller (
    input op_code, // 1'b0 for READ, 1'b1 for WRITE
    input execute, // on execute, perform op
    input clk, // master clk
    input [25:0] sector_address, // multiply this by 512 to get byte address
    input miso,
    input [7:0] byte_in, // byte to write
    output reg cs = 1'b1, // chip select
    output reg [7:0] byte_out = 8'hff, // holds byte being read
    output mosi,
    output reg finished_byte = 1'b0, // indicates a byte has been written or read
    output reg finished_sector = 1'b0, // indicates the op is finished
    output spi_clk
);
    localparam UNINITIALIZED = 5'h00;
    localparam SEND_INIT_NO_OPS = 5'h01;
    localparam SEND_CMD0 = 5'h02;
    localparam AWAIT_CMD0_RES = 5'h03; // don't forget to handle error
    localparam SEND_CMD8 = 5'h04;
    localparam AWAIT_CMD8_RES = 5'h05; // don't forget to handle error
    localparam SEND_ACMD41 = 5'h06;
    localparam AWAIT_ACMD41_RES = 5'h07; // don't forget to handle error

    reg executing = 1'b0;
    reg execute_txrx = 1'b0;
    wire txrx_finished;

    spi_controller SPI_CONT(
        .execute(execute_txrx),
        .clk(clk),
        .miso(miso),
        .out_word(byte_out),
        .spi_clk(spi_clk),
        .mosi(mosi),
        .in_word(byte_in),
        .finished(txrx_finished)
    );

    always @(negedge clk) begin

    end

endmodule