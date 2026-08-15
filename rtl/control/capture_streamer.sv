module capture_streamer #(
    parameter int unsigned CAPTURE_DEPTH = 1024,
    parameter int unsigned INDEX_WIDTH = 64,
    parameter logic [7:0] CAPTURE_PACKET_TYPE = 8'h02,
    parameter logic [7:0] SAMPLE_FORMAT_U12_IN_U16_LE = 8'h01
)(
    input logic clk,
    input logic rst,
    input logic capture_done,
    input logic [INDEX_WIDTH-1:0] capture_start_index,
    input logic [15:0] capture_count,
    output logic [$clog2(CAPTURE_DEPTH)-1:0] capture_read_address,
    input logic [11:0] capture_read_data,

    output logic request_valid,
    output logic [7:0] request_type,
    output logic [15:0] request_length,
    output logic [15:0] request_sequence,
    input logic request_ready,

    output logic payload_valid,
    output logic [7:0] payload_byte,
    input logic payload_ready,
    input logic packet_done,

    output logic streamer_busy
);

localparam int unsigned ADDRESS_WIDTH = (CAPTURE_DEPTH <= 1) ? 1 : $clog2(CAPTURE_DEPTH);
localparam int unsigned METADATA_BYTES = 11;

typedef enum logic [3:0] {
    STREAM_IDLE,
    STREAM_REQUEST,
    STREAM_INDEX,
    STREAM_COUNT_0,
    STREAM_COUNT_1,
    STREAM_FORMAT,
    STREAM_SAMPLE_LOW,
    STREAM_SAMPLE_HIGH,
    STREAM_READ_WAIT,
    STREAM_PACKET_WAIT,
    STREAM_CAPTURE_CLEAR
} streamer_state_t;

streamer_state_t streamer_state;
logic [INDEX_WIDTH-1:0] stored_start_index;
logic [15:0] stored_count;
logic [15:0] stored_sequence;
logic [3:0] index_byte_number;
logic [15:0] sample_number;

assign request_type = CAPTURE_PACKET_TYPE;
assign request_length = METADATA_BYTES + (stored_count << 1);
assign request_sequence = stored_sequence;
assign streamer_busy = streamer_state != STREAM_IDLE && streamer_state != STREAM_CAPTURE_CLEAR;

always_comb begin
    request_valid = 1'b0;
    payload_valid = 1'b0;
    payload_byte = 8'b0;

    case (streamer_state)
        STREAM_REQUEST: begin
            request_valid = 1'b1;
        end

        STREAM_INDEX: begin
            payload_valid = 1'b1;
            payload_byte = stored_start_index[index_byte_number*8 +: 8];
        end

        STREAM_COUNT_0: begin
            payload_valid = 1'b1;
            payload_byte = stored_count[7:0];
        end

        STREAM_COUNT_1: begin
            payload_valid = 1'b1;
            payload_byte = stored_count[15:8];
        end

        STREAM_FORMAT: begin
            payload_valid = 1'b1;
            payload_byte = SAMPLE_FORMAT_U12_IN_U16_LE;
        end

        STREAM_SAMPLE_LOW: begin
            payload_valid = 1'b1;
            payload_byte = capture_read_data[7:0];
        end

        STREAM_SAMPLE_HIGH: begin
            payload_valid = 1'b1;
            payload_byte = {4'b0, capture_read_data[11:8]};
        end

        default: begin
            payload_valid = 1'b0;
        end
    endcase
end

always_ff @(posedge clk) begin
    if (rst) begin
        streamer_state <= STREAM_IDLE;
        stored_start_index <= '0;
        stored_count <= 16'b0;
        stored_sequence <= 16'b0;
        index_byte_number <= 4'b0;
        sample_number <= 16'b0;
        capture_read_address <= '0;
    end else begin
        case (streamer_state)
            STREAM_IDLE: begin
                if (capture_done) begin
                    stored_start_index <= capture_start_index;
                    stored_count <= capture_count;
                    index_byte_number <= 4'b0;
                    sample_number <= 16'b0;
                    capture_read_address <= '0;
                    streamer_state <= STREAM_REQUEST;
                end
            end

            STREAM_REQUEST: begin
                if (request_valid && request_ready)
                    streamer_state <= STREAM_INDEX;
            end

            STREAM_INDEX: begin
                if (payload_valid && payload_ready) begin
                    if (index_byte_number == 7) begin
                        index_byte_number <= 4'b0;
                        streamer_state <= STREAM_COUNT_0;
                    end else begin
                        index_byte_number <= index_byte_number + 1'b1;
                    end
                end
            end

            STREAM_COUNT_0: begin
                if (payload_valid && payload_ready)
                    streamer_state <= STREAM_COUNT_1;
            end

            STREAM_COUNT_1: begin
                if (payload_valid && payload_ready)
                    streamer_state <= STREAM_FORMAT;
            end

            STREAM_FORMAT: begin
                if (payload_valid && payload_ready) begin
                    if (stored_count == 0)
                        streamer_state <= STREAM_PACKET_WAIT;
                    else
                        streamer_state <= STREAM_SAMPLE_LOW;
                end
            end

            STREAM_SAMPLE_LOW: begin
                if (payload_valid && payload_ready)
                    streamer_state <= STREAM_SAMPLE_HIGH;
            end

            STREAM_SAMPLE_HIGH: begin
                if (payload_valid && payload_ready) begin
                    if (sample_number == stored_count-1) begin
                        sample_number <= 16'b0;
                        streamer_state <= STREAM_PACKET_WAIT;
                    end else begin
                        sample_number <= sample_number + 1'b1;
                        capture_read_address <= capture_read_address + 1'b1;
                        streamer_state <= STREAM_READ_WAIT;
                    end
                end
            end

            STREAM_READ_WAIT: begin
                streamer_state <= STREAM_SAMPLE_LOW;
            end

            STREAM_PACKET_WAIT: begin
                if (packet_done) begin
                    stored_sequence <= stored_sequence + 1'b1;
                    streamer_state <= STREAM_CAPTURE_CLEAR;
                end
            end

            STREAM_CAPTURE_CLEAR: begin
                if (!capture_done)
                    streamer_state <= STREAM_IDLE;
            end

            default: begin
                streamer_state <= STREAM_IDLE;
            end
        endcase
    end
end

endmodule
