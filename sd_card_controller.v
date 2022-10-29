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
    // FSM states
    localparam [4:0] UNINITIALIZED = 5'h00;
    localparam [4:0] SEND_INIT_NO_OPS = 5'h01;
    localparam [4:0] SEND_CMD0 = 5'h02;
    localparam [4:0] AWAIT_CMD0_RES = 5'h03; // don't forget to handle error
    localparam [4:0] SEND_CMD8 = 5'h04;
    localparam [4:0] AWAIT_CMD8_RES = 5'h05; // don't forget to handle error
    localparam [4:0] SEND_ACMD41 = 5'h06;
    localparam [4:0] AWAIT_ACMD41_RES = 5'h07; // don't forget to handle error

    // SD commands
    localparam [5:0] CMD0 = 6'd0; // reset SD card
    localparam [5:0] CMD8 = 6'd8; // interface condition (expected voltage, etc)
    localparam [5:0] CMD55 = 6'd55; // precedes app commands - may not be needed
    localparam [5:0] CMD58 = 6'd58; // read OCR, CCS bit assigned

    // SD app commands
    localparam [5:0] ACMD41 = 6'd41; // request card capacity and begin init process

    reg [4:0] cur_state = UNINITIALIZED;
    reg executing = 1'b0;
    reg execute_txrx = 1'b0;
    integer target_count = 0;
    integer cur_count = 0;
    reg [5:0] cur_cmd;
    reg [31:0] cur_args;
    reg [7:0] cur_crc;
    reg initialize_state = 1'b0;
    reg send_no_op = 1'b0;
    wire txrx_finished;
    wire txrx_busy;
    wire [7:0] tx_byte;
    wire [7:0] rx_byte;
    wire [47:0] full_cmd;
    wire [5:0] cmd_ind;

    assign busy = executing;
    assign full_cmd = {1'b0, 1'b1, cur_cmd, cur_args, cur_crc};
    assign tx_byte = send_no_op ? 8'h00 : full_cmd;

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
                initialize_state <= 1'b1;
            end
            SEND_INIT_NO_OPS: begin
                if (initialize_state) begin
                    initialize_state <= 1'b0;

                    target_count <= 80;
                    cur_count <= 0;
                    send_no_op <= 1'b1; // we're just running the clk, no cmd

                    executing <= 1'b1; // let controllers know we're busy
                    execute_txrx <= 1'b1; // start executing txrx sequences
                end else begin
                    if (cur_count >= target_count) begin // once 80 blank bytes have been sent
                        if (txrx_finished) begin // once current sequence completes
                            cur_state <= SEND_CMD0; // change state
                            initialize_state <= 1'b1;
                        end
                    end else if (txrx_finished) begin // once current sequence completes
                        cur_count <= cur_count + 1; // increment count
                        execute_txrx <= 1'b1; // start next txrx sequence
                    end
                end
            end
            SEND_CMD0: begin
                if (initialize_state) begin
                    initialize_state <= 1'b0;

                    target_count <= 6;
                    cur_count <= 0;
                    send_no_op <= 1'b0;

                    cur_cmd <= CMD0;
                    cur_args <= {32{1'b1}};
                    cur_crc <= 8'h95;

                    execute_txrx <= 1'b1;
                end else begin
                    if (cur_count >= target_count) begin
                        if (txrx_finished) begin // once current sequence completes
                            cur_state <= AWAIT_CMD0_RES; // change state
                            initialize_state <= 1'b1;
                        end
                    end else if (txrx_finished) begin
                        cur_count <= cur_count + 1; // increment count
                        execute_txrx <= 1'b1;
                    end
                end
            end
            AWAIT_CMD0_RES: begin
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