module packet_tx #(
    parameter int unsigned MAX_PAYLOAD_BYTES = 4096,
    parameter logic [7:0] PROTOCOL_VERSION = 8'h01,
    parameter logic [7:0] SYNC_BYTE_0 = 8'ha5,
    parameter logic [7:0] SYNC_BYTE_1 = 8'h5a
)(
    input logic clk,
    input logic rst,
    input logic request_valid,
    input logic [7:0] request_type,
    input logic [15:0] request_length,
    input logic [15:0] request_sequence,
    output logic request_ready,

    input logic payload_valid,
    input logic [7:0] payload_byte,
    output logic payload_ready,

    output logic output_valid,
    output logic [7:0] output_byte,
    input logic output_ready,

    output logic packet_busy,
    output logic packet_done,
    output logic packet_error
);

typedef enum logic [3:0] {
    PACKET_IDLE,
    PACKET_SYNC_0,
    PACKET_SYNC_1,
    PACKET_VERSION,
    PACKET_TYPE,
    PACKET_LENGTH_0,
    PACKET_LENGTH_1,
    PACKET_SEQUENCE_0,
    PACKET_SEQUENCE_1,
    PACKET_PAYLOAD,
    PACKET_CRC_0,
    PACKET_CRC_1
} packet_state_t;

packet_state_t packet_state;
logic [7:0] stored_type;
logic [15:0] stored_length;
logic [15:0] stored_sequence;
logic [15:0] payload_count;
logic crc_clear;
logic crc_data_valid;
logic [7:0] crc_data_byte;
logic [15:0] crc_value;
logic output_transfer;

assign request_ready = packet_state == PACKET_IDLE;
assign packet_busy = packet_state != PACKET_IDLE;
assign output_transfer = output_valid && output_ready;

crc16_ccitt crc16_ccitt_inst(
    .clk(clk),
    .rst(rst),
    .clear(crc_clear),
    .data_valid(crc_data_valid),
    .data_byte(crc_data_byte),
    .crc(crc_value)
);

always_comb begin
    output_valid = 1'b0;
    output_byte = 8'b0;
    payload_ready = 1'b0;
    crc_data_valid = 1'b0;
    crc_data_byte = output_byte;

    case (packet_state)
        PACKET_SYNC_0: begin
            output_valid = 1'b1;
            output_byte = SYNC_BYTE_0;
        end

        PACKET_SYNC_1: begin
            output_valid = 1'b1;
            output_byte = SYNC_BYTE_1;
        end

        PACKET_VERSION: begin
            output_valid = 1'b1;
            output_byte = PROTOCOL_VERSION;
            crc_data_valid = output_ready;
            crc_data_byte = PROTOCOL_VERSION;
        end

        PACKET_TYPE: begin
            output_valid = 1'b1;
            output_byte = stored_type;
            crc_data_valid = output_ready;
            crc_data_byte = stored_type;
        end

        PACKET_LENGTH_0: begin
            output_valid = 1'b1;
            output_byte = stored_length[7:0];
            crc_data_valid = output_ready;
            crc_data_byte = stored_length[7:0];
        end

        PACKET_LENGTH_1: begin
            output_valid = 1'b1;
            output_byte = stored_length[15:8];
            crc_data_valid = output_ready;
            crc_data_byte = stored_length[15:8];
        end

        PACKET_SEQUENCE_0: begin
            output_valid = 1'b1;
            output_byte = stored_sequence[7:0];
            crc_data_valid = output_ready;
            crc_data_byte = stored_sequence[7:0];
        end

        PACKET_SEQUENCE_1: begin
            output_valid = 1'b1;
            output_byte = stored_sequence[15:8];
            crc_data_valid = output_ready;
            crc_data_byte = stored_sequence[15:8];
        end

        PACKET_PAYLOAD: begin
            output_valid = payload_valid;
            output_byte = payload_byte;
            payload_ready = output_ready;
            crc_data_valid = payload_valid && output_ready;
            crc_data_byte = payload_byte;
        end

        PACKET_CRC_0: begin
            output_valid = 1'b1;
            output_byte = crc_value[7:0];
        end

        PACKET_CRC_1: begin
            output_valid = 1'b1;
            output_byte = crc_value[15:8];
        end

        default: begin
            output_valid = 1'b0;
        end
    endcase
end

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        packet_state <= PACKET_IDLE;
        stored_type <= 8'b0;
        stored_length <= 16'b0;
        stored_sequence <= 16'b0;
        payload_count <= 16'b0;
        crc_clear <= 1'b1;
        packet_done <= 1'b0;
        packet_error <= 1'b0;
    end else begin
        crc_clear <= 1'b0;
        packet_done <= 1'b0;

        case (packet_state)
            PACKET_IDLE: begin
                payload_count <= 16'b0;

                if (request_valid) begin
                    if (request_length > MAX_PAYLOAD_BYTES) begin
                        packet_error <= 1'b1;
                        packet_done <= 1'b1;
                    end else begin
                        stored_type <= request_type;
                        stored_length <= request_length;
                        stored_sequence <= request_sequence;
                        crc_clear <= 1'b1;
                        packet_state <= PACKET_SYNC_0;
                    end
                end
            end

            PACKET_SYNC_0: begin
                if (output_transfer)
                    packet_state <= PACKET_SYNC_1;
            end

            PACKET_SYNC_1: begin
                if (output_transfer)
                    packet_state <= PACKET_VERSION;
            end

            PACKET_VERSION: begin
                if (output_transfer)
                    packet_state <= PACKET_TYPE;
            end

            PACKET_TYPE: begin
                if (output_transfer)
                    packet_state <= PACKET_LENGTH_0;
            end

            PACKET_LENGTH_0: begin
                if (output_transfer)
                    packet_state <= PACKET_LENGTH_1;
            end

            PACKET_LENGTH_1: begin
                if (output_transfer)
                    packet_state <= PACKET_SEQUENCE_0;
            end

            PACKET_SEQUENCE_0: begin
                if (output_transfer)
                    packet_state <= PACKET_SEQUENCE_1;
            end

            PACKET_SEQUENCE_1: begin
                if (output_transfer) begin
                    if (stored_length == 0)
                        packet_state <= PACKET_CRC_0;
                    else
                        packet_state <= PACKET_PAYLOAD;
                end
            end

            PACKET_PAYLOAD: begin
                if (output_transfer) begin
                    if (payload_count == stored_length-1) begin
                        payload_count <= 16'b0;
                        packet_state <= PACKET_CRC_0;
                    end else begin
                        payload_count <= payload_count + 1'b1;
                    end
                end
            end

            PACKET_CRC_0: begin
                if (output_transfer)
                    packet_state <= PACKET_CRC_1;
            end

            PACKET_CRC_1: begin
                if (output_transfer) begin
                    packet_done <= 1'b1;
                    packet_state <= PACKET_IDLE;
                end
            end

            default: begin
                packet_error <= 1'b1;
                packet_state <= PACKET_IDLE;
            end
        endcase
    end
end

endmodule
