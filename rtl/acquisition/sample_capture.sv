module sample_capture #(
    parameter int unsigned DEPTH = 1024,
    parameter int unsigned INDEX_WIDTH = 64
)(
    input logic clk,
    input logic rst,
    input logic arm,
    input logic trigger,
    input logic sample_valid,
    input logic [11:0] sample_u12,
    input logic [INDEX_WIDTH-1:0] sample_index,
    input logic [$clog2(DEPTH)-1:0] read_address,

    output logic [11:0] read_data,
    output logic capture_armed,
    output logic capture_busy,
    output logic capture_done,
    output logic trigger_rejected,
    output logic [INDEX_WIDTH-1:0] capture_start_index,
    output logic [15:0] capture_count
);

localparam int unsigned ADDRESS_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);

typedef enum logic [1:0] {
    CAPTURE_IDLE,
    CAPTURE_ARMED,
    CAPTURE_ACTIVE,
    CAPTURE_COMPLETE
} capture_state_t;

capture_state_t capture_state;
logic [11:0] sample_memory [0:DEPTH-1];
logic [ADDRESS_WIDTH-1:0] write_address;
logic memory_write_enable;
logic [ADDRESS_WIDTH-1:0] memory_write_address;
logic [11:0] memory_write_data;

assign capture_armed = capture_state == CAPTURE_ARMED;
assign capture_busy = capture_state == CAPTURE_ACTIVE;

always_ff @(posedge clk) begin
    if (rst) begin
        memory_write_enable <= 1'b0;
        memory_write_address <= '0;
        memory_write_data <= 12'b0;
    end else begin
        memory_write_enable <= capture_state == CAPTURE_ACTIVE && sample_valid;

        if (capture_state == CAPTURE_ACTIVE && sample_valid) begin
            memory_write_address <= write_address;
            memory_write_data <= sample_u12;
        end
    end
end

always_ff @(posedge clk) begin
    if (memory_write_enable)
        sample_memory[memory_write_address] <= memory_write_data;
end

always_ff @(posedge clk) begin
    read_data <= sample_memory[read_address];
end

always_ff @(posedge clk) begin
    if (rst) begin
        capture_state <= CAPTURE_IDLE;
        write_address <= '0;
        capture_done <= 1'b0;
        trigger_rejected <= 1'b0;
        capture_start_index <= '0;
        capture_count <= 16'b0;
    end else begin
        case (capture_state)
            CAPTURE_IDLE: begin
                if (trigger)
                    trigger_rejected <= 1'b1;

                if (arm) begin
                    write_address <= '0;
                    capture_done <= 1'b0;
                    trigger_rejected <= 1'b0;
                    capture_start_index <= '0;
                    capture_count <= 16'b0;
                    capture_state <= CAPTURE_ARMED;
                end
            end

            CAPTURE_ARMED: begin
                if (arm) begin
                    write_address <= '0;
                    capture_done <= 1'b0;
                    trigger_rejected <= 1'b0;
                    capture_start_index <= '0;
                    capture_count <= 16'b0;
                end

                if (trigger)
                    capture_state <= CAPTURE_ACTIVE;
            end

            CAPTURE_ACTIVE: begin
                if (arm || trigger)
                    trigger_rejected <= 1'b1;

                if (sample_valid) begin
                    if (write_address == 0)
                        capture_start_index <= sample_index;

                    if (write_address == DEPTH-1) begin
                        capture_count <= DEPTH;
                        capture_done <= 1'b1;
                        capture_state <= CAPTURE_COMPLETE;
                    end else begin
                        write_address <= write_address + 1'b1;
                        capture_count <= capture_count + 1'b1;
                    end
                end
            end

            CAPTURE_COMPLETE: begin
                if (trigger)
                    trigger_rejected <= 1'b1;

                if (arm) begin
                    write_address <= '0;
                    capture_done <= 1'b0;
                    trigger_rejected <= 1'b0;
                    capture_start_index <= '0;
                    capture_count <= 16'b0;
                    capture_state <= CAPTURE_ARMED;
                end
            end

            default: begin
                capture_state <= CAPTURE_IDLE;
                capture_done <= 1'b0;
                trigger_rejected <= 1'b1;
            end
        endcase
    end
end

endmodule
