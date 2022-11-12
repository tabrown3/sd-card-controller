module fat32_controller (
    input [63:0] filename, // 8 bytes for name
    input [23:0] extension, // 3 bytes for extension
    input [31:0] file_size, // bytes
    input op_code,
    input execute,
    input clk,
    input [7:0] outgoing_byte,
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
    localparam [4:0] UNINITIALIZED = 5'h00;
    localparam [4:0] AWAIT_SD_CARD_INIT = 5'h01;
    localparam [4:0] READ_MBR = 5'h02;
    localparam [4:0] READ_VOLUME_ID = 5'h03;
    localparam [4:0] READ_ROOT_DIR = 5'h04;

    // SDCC0 input deps
    reg sd_op_code;
    reg sd_execute_reg = 1'b0;
    reg p_sd_execute = 1'b0;
    reg [31:0] sector_address;
    reg [7:0] sd_outgoing_byte = 8'haa; // this is dummy data
    reg init_sd_card = 1'b1;

    // other regs
    reg [4:0] cur_state = UNINITIALIZED;
    reg initialize_state = 1'b1;
    reg executing = 1'b0;
    reg prev_sd_busy = 1'b0;
    // TODO - remove noprune
    reg [9:0] cur_byte_count = 0 /* synthesis noprune */;
    reg [31:0] partition_lba_begin = 0 /* synthesis noprune */;
    reg [15:0] num_reserved_sectors = 0 /* synthesis noprune */;
    reg [31:0] sectors_per_fat = 0 /* synthesis noprune */;
    reg [7:0] sectors_per_cluster = 0 /* synthesis noprune */;
    reg [31:0] root_dir_first_cluster = 0 /* synthesis noprune */;
    
    // SDCC0 output deps
    wire [7:0] sd_incoming_byte;
    wire sd_finished_byte;
    wire sd_finished_block;
    wire sd_busy;

    // other wires
    wire sd_execute;

    // Controller Logic - Start
    assign busy = executing;
    assign sd_execute = sd_execute_reg ^ p_sd_execute;

    wire [31:0] fat_begin_lba = partition_lba_begin + num_reserved_sectors;
    wire [31:0] cluster_begin_lba = fat_begin_lba + 2*sectors_per_fat;

    sd_card_controller SDCC0 (
        .op_code(sd_op_code),
        .execute(sd_execute),
        .clk(clk),
        .block_address(sector_address),
        .miso(miso),
        .outgoing_byte(sd_outgoing_byte),
        .btn(init_sd_card),
        .cs(cs),
        .incoming_byte(sd_incoming_byte),
        .mosi(mosi),
        .finished_byte(sd_finished_byte),
        .finished_block(sd_finished_block),
        .spi_clk(spi_clk),
        .busy(sd_busy)
    );

    always @(negedge clk) begin
        case (cur_state)
            UNINITIALIZED: begin
                if (execute) begin
                    init_sd_card <= 1'b0; // kick off sd card init
                    executing <= 1'b1;
                    transition_to(AWAIT_SD_CARD_INIT);
                end
            end
            AWAIT_SD_CARD_INIT: begin
                if (!sd_busy && prev_sd_busy) begin // equivalent to sync negedge sd_busy
                    transition_to(READ_MBR);
                end

                prev_sd_busy <= sd_busy;
            end
            READ_MBR: begin
                if (initialize_state) begin
                    initialize_state <= 1'b0;

                    sector_address <= {32{1'b0}}; // Master Boot Record at sector zero
                    sd_op_code <= 1'b0; // READ

                    cur_byte_count <= 0;
                    partition_lba_begin = {32{1'b0}};
                    sd_execute_reg <= ~sd_execute_reg;
                end else begin
                    if (sd_finished_byte) begin
                        if (in_window(cur_byte_count, 454, 4)) begin
                            partition_lba_begin <= {sd_incoming_byte, partition_lba_begin[31:8]};
                        end
                        cur_byte_count <= cur_byte_count + 1;
                    end else if (sd_finished_block) begin
                        transition_to(READ_VOLUME_ID);
                    end
                end
            end
            READ_VOLUME_ID: begin
                if (initialize_state) begin
                    initialize_state <= 1'b0;

                    sector_address <= partition_lba_begin;
                    sd_op_code <= 1'b0; // READ

                    cur_byte_count <= 0;
                    sd_execute_reg <= ~sd_execute_reg;
                end else begin
                    if (sd_finished_byte) begin
                        if (in_window(cur_byte_count, 8'h0d, 1)) begin
                            sectors_per_cluster <= sd_incoming_byte;
                        end else if (in_window(cur_byte_count, 8'h0e, 2)) begin
                            num_reserved_sectors <= {sd_incoming_byte, num_reserved_sectors[15:8]};
                        end else if (in_window(cur_byte_count, 8'h24, 4)) begin
                            sectors_per_fat <= {sd_incoming_byte, sectors_per_fat[31:8]};
                        end else if (in_window(cur_byte_count, 8'h2c, 4)) begin
                            root_dir_first_cluster <= {sd_incoming_byte, root_dir_first_cluster[31:8]};
                        end
                        cur_byte_count <= cur_byte_count + 1;
                    end else if (sd_finished_block) begin
                        transition_to(READ_ROOT_DIR);
                    end
                end
            end
            READ_ROOT_DIR: begin
            end
            default: begin
                transition_to(UNINITIALIZED);
            end
        endcase

        p_sd_execute <= sd_execute_reg;
    end

    task transition_to (input [4:0] next_state);
        begin
            initialize_state <= 1'b1;
            cur_state <= next_state;
        end
    endtask

    function in_window (
        input [9:0] index, // the index to compare
        input [9:0] start_ind, // the first index that's within the window
        input [9:0] width // the window width
    );
        begin
            in_window = index >= start_ind && index <= (start_ind + width - 1);
        end
    endfunction


endmodule