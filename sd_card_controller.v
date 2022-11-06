module sd_card_controller (
    input op_code, // 1'b0 for READ, 1'b1 for WRITE
    input execute, // on execute, perform op
    input clk, // master clk
    input [31:0] block_address,
    input miso,
    input [7:0] outgoing_byte, // byte to write
    input btn,
    output cs, // chip select
    output reg [7:0] incoming_byte, // holds byte being read
    output mosi,
    output finished_byte, // indicates a byte has been written or read
    output finished_block, // indicates the op is finished
    output spi_clk,
    output busy
);
    // FSM states
    localparam [4:0] UNINITIALIZED = 5'h00;
    localparam [4:0] SEND_X_NO_OPS = 5'h01;
    localparam [4:0] SEND_CMD0 = 5'h02;
    localparam [4:0] PROCESS_CMD0_RES = 5'h03;
    localparam [4:0] SEND_CMD8 = 5'h04;
    localparam [4:0] PROCESS_CMD8_RES = 5'h05;
    localparam [4:0] SEND_CMD55 = 5'h06;
    localparam [4:0] PROCESS_CMD55_RES = 5'h07;
    localparam [4:0] SEND_ACMD41 = 5'h08;
    localparam [4:0] PROCESS_ACMD41_RES = 5'h09;
    localparam [4:0] SEND_CMD58 = 5'h0a;
    localparam [4:0] PROCESS_CMD58_RES = 5'h0b;
    localparam [4:0] FINISH_INIT = 5'h0c;
    localparam [4:0] READY_AND_WAITING = 5'h0d;
    localparam [4:0] SEND_CMD17 = 5'h0e;
    localparam [4:0] PROCESS_CMD17_RES = 5'h0f;
    localparam [4:0] SEND_CMD24 = 5'h10;
    localparam [4:0] PROCESS_CMD24_RES = 5'h11;
    localparam [4:0] TERMINAL_STATE = 5'h12;

    // SD commands
    localparam [5:0] CMD0 = 6'd0; // reset SD card
    localparam [5:0] CMD8 = 6'd8; // interface condition (expected voltage, etc)
    localparam [5:0] CMD17 = 6'd17; // read single block
    localparam [5:0] CMD24 = 6'd24; // write single block
    localparam [5:0] CMD55 = 6'd55; // precedes app commands
    localparam [5:0] CMD58 = 6'd58; // read OCR, CCS bit assigned

    // SD app commands
    localparam [5:0] ACMD41 = 6'd41; // request card capacity and begin init process

    reg [4:0] cur_state = UNINITIALIZED;
    reg [4:0] redirect_to = UNINITIALIZED; // ignored most of the time
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
    reg [7:0] out_byte_buffer;
    reg cs_reg = 1'b1;
    reg await_res = 1'b0;
    reg [39:0] res_buffer = {40{1'b0}};
    reg reading_res = 1'b0;
    reg finished_byte_reg = 1'b0;
    reg p_finished_byte = 1'b0;
    reg finished_block_reg = 1'b0;
    reg p_finished_block = 1'b0;
    reg is_first_cmd_byte = 1'b1;
    wire txrx_finished;
    wire txrx_busy;
    wire [7:0] tx_byte;
    wire [7:0] rx_byte;
    wire [47:0] full_cmd;
    wire [5:0] cmd_ind;
    wire [7:0] r1_res;

    wire execute_txrx = p_execute_txrx ^ execute_txrx_reg;

    assign busy = executing;
    assign full_cmd = {1'b0, 1'b1, cur_cmd, cur_args, cur_crc, 1'b1};
    assign tx_byte = send_no_op ? 8'hff : out_byte_buffer;
    assign cs = cs_reg;
    assign r1_res = res_buffer[39:32];
    assign finished_byte = p_finished_byte ^ finished_byte_reg;
    assign finished_block = p_finished_block ^ finished_block_reg;

    spi_controller SPI_CONT(
        .execute(execute_txrx),
        .clk(clk),
        .miso(miso),
        .out_word(tx_byte),
        .spi_clk(spi_clk),
        .mosi(mosi),
        .in_word(rx_byte),
        .finished(txrx_finished),
        .busy(txrx_busy)
    );

    always @(negedge clk) begin
        case (cur_state)
            UNINITIALIZED: begin
                cs_reg <= 1'b1;
                if (!btn) begin
                    target_count <= 80;
                    await_res <= 1'b0;
                    transition_to(SEND_X_NO_OPS, SEND_CMD0);
                end
            end
            SEND_X_NO_OPS: begin
                send_no_ops(
                    target_count,
                    5,
                    rx_byte == 8'h01 || rx_byte == 8'h00,
                    1'b0
                );
            end
            SEND_CMD0: begin
                send_cmd(
                    CMD0,
                    {32{1'b0}},
                    7'h4a,
                    PROCESS_CMD0_RES
                );
            end
            PROCESS_CMD0_RES: begin
                cs_reg <= 1'b1;
                target_count <= 4;
                await_res <= 1'b0;
                transition_to(SEND_X_NO_OPS, SEND_CMD8);
            end
            SEND_CMD8: begin
                send_cmd(
                    CMD8,
                    {{16{1'b0}}, 8'h01, 8'b10101010},
                    7'b1000011,
                    PROCESS_CMD8_RES
                );
            end
            PROCESS_CMD8_RES: begin
                cs_reg <= 1'b1;
                target_count <= 4;
                await_res <= 1'b0;
                transition_to(SEND_X_NO_OPS, SEND_CMD55);
            end
            SEND_CMD55: begin
                send_cmd(
                    CMD55,
                    {32{1'b0}},
                    7'h00,
                    PROCESS_CMD55_RES
                );
            end
            PROCESS_CMD55_RES: begin
                cs_reg <= 1'b1;
                target_count <= 4;
                await_res <= 1'b0;
                transition_to(SEND_X_NO_OPS, SEND_ACMD41);
            end
            SEND_ACMD41: begin
                send_cmd(
                    ACMD41,
                    {2'b01, {30{1'b0}}}, // bit 30 is HCS, which we want - rest are 0
                    7'h00,
                    PROCESS_ACMD41_RES
                );
            end
            PROCESS_ACMD41_RES: begin
                cs_reg <= 1'b1;

                if (!r1_res) begin // when R1 is all 0's
                    target_count <= 4;
                    await_res <= 1'b0;
                    transition_to(SEND_X_NO_OPS, SEND_CMD58); // move to next CMD
                end else begin
                    target_count <= 80;
                    await_res <= 1'b0;
                    transition_to(SEND_X_NO_OPS, SEND_CMD55); // keep sending init CMDs
                end
            end
            SEND_CMD58: begin
                send_cmd(
                    CMD58,
                    {32{1'b0}},
                    7'h00,
                    PROCESS_CMD58_RES
                );
            end
            PROCESS_CMD58_RES: begin
                cs_reg <= 1'b1;
                target_count <= 4;
                await_res <= 1'b0;
                transition_to(SEND_X_NO_OPS, FINISH_INIT);
            end
            FINISH_INIT: begin // TODO: Is FINISH_INIT needed?
                cs_reg <= 1'b1;
                target_count <= 80;
                await_res <= 1'b0;
                transition_to(SEND_X_NO_OPS, READY_AND_WAITING);
            end
            READY_AND_WAITING: begin
                if (execute && !executing) begin
                    executing <= 1'b1;

                    if (op_code) begin // WRITE
                        transition_to(SEND_CMD24, SEND_CMD24);
                    end else begin // READ
                        transition_to(SEND_CMD17, SEND_CMD17);
                    end
                end else if (executing) begin
                    executing <= 1'b0;
                    cs_reg <= 1'b1;
                end
            end
            SEND_CMD17: begin // READ
                send_cmd(
                    CMD17,
                    block_address,
                    7'h00,
                    PROCESS_CMD17_RES
                );
            end
            PROCESS_CMD17_RES: begin
                redirect_to <= READY_AND_WAITING;
                send_no_ops(
                    1000,
                    515,
                    rx_byte == 8'hfe,
                    1'b1
                );
            end
            SEND_CMD24: begin
                send_cmd(
                    CMD24,
                    block_address,
                    7'h00,
                    PROCESS_CMD24_RES
                );
            end
            PROCESS_CMD24_RES: begin
                if (initialize_state) begin
                    initialize_state <= 1'b0;

                    target_count <= 513;
                    cur_count <= 1;
                    out_byte_buffer <= 8'hfe;
                    send_no_op <= 1'b0;

                    execute_txrx_reg <= ~execute_txrx_reg; // start executing txrx sequences
                    cs_reg <= 1'b0;
                end else begin
                    if (cur_count >= target_count) begin
                        if (txrx_finished) begin // once current sequence completes
                            target_count <= 80;
                            finished_byte_reg <= ~finished_byte_reg;
                            finished_block_reg <= ~finished_block_reg;
                            await_res <= 1'b0;
                            transition_to(SEND_X_NO_OPS, READY_AND_WAITING);
                        end
                    end else if (txrx_finished) begin
                        out_byte_buffer <= outgoing_byte;
                        cur_count <= cur_count + 1; // increment count
                        finished_byte_reg <= ~finished_byte_reg;

                        execute_txrx_reg <= ~execute_txrx_reg;
                    end
                end
            end
            TERMINAL_STATE: begin
            end
            default: begin
                transition_to(UNINITIALIZED, UNINITIALIZED);
                target_count <= 0;
                cur_count <= 0;
                executing <= 1'b1;
                // consider sending error
            end
        endcase

        p_execute_txrx <= execute_txrx_reg;
        p_finished_byte <= finished_byte_reg;
        p_finished_block <= finished_block_reg;
    end

    task transition_to (input [4:0] transition_target, input [4:0] redirect_target);
        begin
            cur_state <= transition_target;
            redirect_to <= redirect_target;
            initialize_state <= 1'b1;
        end
    endtask

    task send_no_ops (
        input integer blank_target_count, // target count when not awaiting res, or until res is read
        input integer res_target_count, // target count after res is read (if ever)
        input is_first_res_byte, // this is the result of a res identifying expression
        input is_read_token // this flag indicates that we're waiting for a read token (as opposed to an R1, R3, etc)
    );
        begin
            if (initialize_state) begin
                initialize_state <= 1'b0;

                cur_count <= 0;
                send_no_op <= 1'b1; // we're just running the clk, no cmd
                reading_res <= 1'b0;

                executing <= 1'b1; // let controllers know we're busy
                execute_txrx_reg <= ~execute_txrx_reg; // start executing txrx sequences
            end else begin
                // If await_res is 0, blank_target_count is the number of no-op clk bytes to send
                // If await_res is 1, blank_target_count is a sort of timeout leading up to the
                //  the expected response. Once the expecte response is identified, reading_res
                //  becomes 1 and res_target_count replaces blank_target_count as the terminating
                //  count.
                if (cur_count >= blank_target_count || (reading_res && cur_count >= res_target_count)) begin
                    if (txrx_finished) begin // once current sequence completes
                        if (reading_res) begin
                            if (is_read_token) begin
                                finished_block_reg <= ~finished_block_reg;
                            end

                            store_rx_byte(is_read_token);
                        end

                        reading_res <= 1'b0;
                        transition_to(redirect_to, redirect_to);
                    end
                end else if (txrx_finished) begin // once current sequence completes
                    if (reading_res) begin
                        store_rx_byte(is_read_token);
                    end

                    if (is_first_res_byte && await_res && !reading_res) begin // if the card responded
                        reading_res <= 1'b1;
                        target_count <= res_target_count;
                        cur_count <= 2; // skip the first byte since we already have it

                        store_rx_byte(is_read_token);
                    end else begin // else keep sending no_ops
                        cur_count <= cur_count + 1; // increment count
                    end

                    execute_txrx_reg <= ~execute_txrx_reg; // start next txrx sequence
                end
            end
        end
    endtask

    task send_cmd (
        input [5:0] in_cmd,
        input [31:0] in_args,
        input [6:0] in_crc,
        input [4:0] in_redirect_target
    );
        begin
            if (initialize_state) begin
                initialize_state <= 1'b0;

                target_count <= 6;
                cur_count <= 0;
                send_no_op <= 1'b0;

                cur_cmd <= in_cmd;
                cur_args <= in_args;
                cur_crc <= in_crc;
                out_byte_buffer <= {1'b0, 1'b1, in_cmd};
                is_first_cmd_byte <= 1'b1;

                cs_reg <= 1'b0;
            end else begin
                if (cur_count >= target_count) begin
                    if (txrx_finished) begin // once current sequence completes
                        target_count <= 80;
                        await_res <= 1'b1;
                        transition_to(SEND_X_NO_OPS, in_redirect_target);
                    end
                end else if (txrx_finished || is_first_cmd_byte) begin
                    is_first_cmd_byte <= 1'b0;
                    out_byte_buffer <= full_cmd[6'd48 - cur_count*4'd8 - 1'b1-:8];
                    cur_count <= cur_count + 1; // increment count
                    execute_txrx_reg <= ~execute_txrx_reg;
                end
            end
        end
    endtask

    task store_rx_byte(input is_read_token);
        begin
            if (is_read_token) begin
                finished_byte_reg <= ~finished_byte_reg;
                incoming_byte <= rx_byte;
            end else begin
                res_buffer <= {res_buffer[31:0], rx_byte}; // save res byte to buffer
            end
        end
    endtask
endmodule