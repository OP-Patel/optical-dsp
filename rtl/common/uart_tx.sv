module uart_tx #(
    parameter int unsigned CLOCK_HZ = 100_000_000,
    parameter int unsigned BAUD = 115_200
)(
    input logic clk,
    input logic rst,
    input logic data_valid,
    input logic [7:0] data_byte,

    output logic data_ready,
    output logic tx,
    output logic busy
);

localparam int unsigned CLKS_PER_BIT = (CLOCK_HZ + (BAUD / 2)) / BAUD;
localparam int unsigned CLOCK_COUNTER_WIDTH = (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);

typedef enum logic [1:0] {
    UART_IDLE,
    UART_START,
    UART_DATA,
    UART_STOP
} uart_state_t;

uart_state_t uart_state;
logic [CLOCK_COUNTER_WIDTH-1:0] clock_counter;
logic [2:0] bit_index;
logic [7:0] shift_register;

assign data_ready = uart_state == UART_IDLE;
assign busy = uart_state != UART_IDLE;

always_comb begin
    case (uart_state)
        UART_START: tx = 1'b0;
        UART_DATA: tx = shift_register[0];
        default: tx = 1'b1;
    endcase
end

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        uart_state <= UART_IDLE;
        clock_counter <= '0;
        bit_index <= 3'b0;
        shift_register <= 8'b0;
    end else begin
        case (uart_state)
            UART_IDLE: begin
                clock_counter <= '0;
                bit_index <= 3'b0;

                if (data_valid) begin
                    shift_register <= data_byte;
                    uart_state <= UART_START;
                end
            end

            UART_START: begin
                if (clock_counter == CLKS_PER_BIT-1) begin
                    clock_counter <= '0;
                    uart_state <= UART_DATA;
                end else begin
                    clock_counter <= clock_counter + 1'b1;
                end
            end

            UART_DATA: begin
                if (clock_counter == CLKS_PER_BIT-1) begin
                    clock_counter <= '0;
                    shift_register <= {1'b0, shift_register[7:1]};

                    if (bit_index == 3'd7) begin
                        bit_index <= 3'b0;
                        uart_state <= UART_STOP;
                    end else begin
                        bit_index <= bit_index + 1'b1;
                    end
                end else begin
                    clock_counter <= clock_counter + 1'b1;
                end
            end

            UART_STOP: begin
                if (clock_counter == CLKS_PER_BIT-1) begin
                    clock_counter <= '0;
                    uart_state <= UART_IDLE;
                end else begin
                    clock_counter <= clock_counter + 1'b1;
                end
            end

            default: begin
                uart_state <= UART_IDLE;
                clock_counter <= '0;
                bit_index <= 3'b0;
            end
        endcase
    end
end

endmodule
