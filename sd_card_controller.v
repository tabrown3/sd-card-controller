module sd_card_controller (
    input op_code, // 1'b0 for READ, 1'b1 for WRITE
    input execute, // on execute, perform op
    input clk, // master clk
    input [25:0] sector_address, // multiply this by 512 to get byte address
    input miso,
    input [7:0] outgoing_byte, // byte to write
    output reg cs = 1'b1, // chip select
    output [7:0] incoming_byte, // holds byte being read
    output mosi,
    output reg finished_byte = 1'b0, // indicates a byte has been written or read
    output reg finished_sector = 1'b0, // indicates the op is finished
    output spi_clk,
    output busy
);
    localparam UNINITIALIZED = 5'h00;
    localparam SEND_INIT_NO_OPS = 5'h01;
    localparam SEND_CMD0 = 5'h02;
    localparam AWAIT_CMD0_RES = 5'h03; // don't forget to handle error
    localparam SEND_CMD8 = 5'h04;
    localparam AWAIT_CMD8_RES = 5'h05; // don't forget to handle error
    localparam SEND_ACMD41 = 5'h06;
    localparam AWAIT_ACMD41_RES = 5'h07; // don't forget to handle error

    reg [4:0] cur_state = UNINITIALIZED;
    reg executing = 1'b0;
    reg execute_txrx = 1'b0;
    integer target_count = 0;
    integer cur_count = 0;
    wire txrx_finished;
    wire txrx_busy;
    wire [7:0] tx_byte;
    wire [7:0] rx_byte;

    assign busy = executing;
    assign tx_byte = SEND_INIT_NO_OPS ? 8'hff : outgoing_byte;

    spi_controller SPI_CONT(
        .execute(execute_txrx),
        .clk(clk),
        .miso(miso),
        .out_word(tx_byte),
        .spi_clk(spi_clk),
        .mosi(mosi),
        .in_word(incoming_byte),
        .finished(txrx_finished),
        .busy(txrx_busy)
    );

    always @(negedge clk) begin
        if (execute_txrx) begin
            execute_txrx <= 1'b0;
        end

        case (cur_state)
            UNINITIALIZED: begin
                cur_state <= SEND_INIT_NO_OPS;
                target_count <= 80;
                cur_count <= 0;
                executing <= 1'b1; // let controllers know we're busy
                execute_txrx <= 1'b1; // start executing txrx sequences
            end
            SEND_INIT_NO_OPS: begin
                if (cur_count >= target_count) begin // once 80 blank bytes have been sent
                    if (txrx_finished) begin // once current sequence completes
                        cur_state <= SEND_CMD0; // change state
                        target_count <= 0;
                        cur_count <= 0;
                    end
                end else if (txrx_finished) begin // once current sequence completes
                    cur_count <= cur_count + 1; // increment count
                    execute_txrx <= 1'b1; // start next txrx sequence
                end
            end
            default: begin
                cur_state <= SEND_CMD0;
                target_count <= 0;
                cur_count <= 0;
                executing <= 1'b1;
                // consider sending error
            end
        endcase
    end

endmodule