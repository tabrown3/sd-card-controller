module sd_card_controller (
    input op_code, // 1'b0 for READ, 1'b1 for WRITE
    input execute, // on execute, perform op
    input clk, // master clk
    input [25:0] sector_address, // multiply this by 512 to get byte address
    input miso,
    input [7:0] outgoing_byte, // byte to write
    input btn,
    output cs, // chip select
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
    reg execute_txrx_reg = 1'b0;
    reg p_execute_txrx = 1'b0;
    integer target_count = 0;
    integer cur_count = 0;
    reg [5:0] cur_cmd;
    reg [31:0] cur_args;
    reg [6:0] cur_crc;
    reg initialize_state = 1'b0;
    reg send_no_op = 1'b0;
    reg [7:0] cmd_byte_buffer;
    reg cs_reg = 1'b1;
    wire txrx_finished;
    wire txrx_busy;
    wire [7:0] tx_byte;
    wire [7:0] rx_byte;
    wire [47:0] full_cmd;
    wire [5:0] cmd_ind;

    wire execute_txrx = p_execute_txrx ^ execute_txrx_reg;

    assign busy = executing;
    assign full_cmd = {1'b0, 1'b1, cur_cmd, cur_args, cur_crc, 1'b1};
    assign tx_byte = send_no_op ? 8'hff : cmd_byte_buffer;
    assign cs = cs_reg;

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
        case (cur_state)
            UNINITIALIZED: begin
                cs_reg <= 1'b1;
                if (!btn) begin
                    transition_to(SEND_INIT_NO_OPS);
                end
            end
            SEND_INIT_NO_OPS: begin
                send_no_ops(80, SEND_CMD0);
            end
            SEND_CMD0: begin
                if (initialize_state) begin
                    initialize_state <= 1'b0;

                    target_count <= 6;
                    cur_count <= 1;
                    send_no_op <= 1'b0;

                    cur_cmd <= CMD0;
                    cur_args <= {32{1'b0}};
                    cur_crc <= 7'h4a;
                    cmd_byte_buffer <= {1'b0, 1'b1, CMD0};

                    execute_txrx_reg <= ~execute_txrx_reg;
                    cs_reg <= 1'b0;
                end else begin
                    if (cur_count >= target_count) begin
                        if (txrx_finished) begin // once current sequence completes
                            transition_to(AWAIT_CMD0_RES);
                            // cs_reg <= 1'b1;
                        end
                    end else if (txrx_finished) begin
                        cmd_byte_buffer <= full_cmd[6'd48 - cur_count*4'd8 - 1'b1-:8];
                        cur_count <= cur_count + 1; // increment count
                        execute_txrx_reg <= ~execute_txrx_reg;
                    end
                end
            end
            AWAIT_CMD0_RES: begin
                send_no_ops(80, SEND_CMD8);
            end
            SEND_CMD8: begin
            end
            default: begin
                transition_to(SEND_CMD0);
                target_count <= 0;
                cur_count <= 0;
                executing <= 1'b1;
                // consider sending error
            end
        endcase

        p_execute_txrx <= execute_txrx_reg;
    end

    task transition_to (input [4:0] next_state);
        begin
            cur_state <= next_state;
            initialize_state <= 1'b1;
        end
    endtask

    task send_no_ops (input integer count_to, input [4:0] next_state);
        begin
            if (initialize_state) begin
                initialize_state <= 1'b0;

                target_count <= count_to;
                cur_count <= 0;
                send_no_op <= 1'b1; // we're just running the clk, no cmd

                executing <= 1'b1; // let controllers know we're busy
                execute_txrx_reg <= ~execute_txrx_reg; // start executing txrx sequences
            end else begin
                if (cur_count >= target_count) begin // once 80 blank bytes have been sent
                    if (txrx_finished) begin // once current sequence completes
                        transition_to(next_state);
                    end
                end else if (txrx_finished) begin // once current sequence completes
                    cur_count <= cur_count + 1; // increment count
                    execute_txrx_reg <= ~execute_txrx_reg; // start next txrx sequence
                end
            end
        end
    endtask
endmodule