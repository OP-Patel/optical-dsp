module xadc_drp_controller #(
    parameter int unsigned TIMEOUT_CYCLES = 256,
    parameter int unsigned INDEX_WIDTH = 64
)(
    input logic clk,
    input logic rst,
    input logic xadc_eoc,
    input logic xadc_drdy,
    input logic [15:0] xadc_do,

    output logic xadc_den,
    output logic [6:0] xadc_daddr,
    output logic [11:0] sample_u12,
    output logic sample_valid,
    output logic [INDEX_WIDTH-1:0] sample_index,
    output logic xadc_busy,
    output logic xadc_fault
);

localparam int unsigned TIMEOUT_WIDTH = (TIMEOUT_CYCLES <= 1) ? 1 : $clog2(TIMEOUT_CYCLES);
localparam logic [6:0] VAUX4_ADDRESS = 7'h14;

typedef enum logic {
    WAIT_EOC,
    WAIT_DRDY
} xadc_controller_state_t;

xadc_controller_state_t controller_state;
logic [TIMEOUT_WIDTH-1:0] timeout_counter;
logic [INDEX_WIDTH-1:0] next_index;

assign xadc_daddr = VAUX4_ADDRESS;
assign xadc_busy = controller_state == WAIT_DRDY;

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        controller_state <= WAIT_EOC;
        timeout_counter <= '0;
        next_index <= '0;
        xadc_den <= 1'b0;
        sample_u12 <= 12'b0;
        sample_valid <= 1'b0;
        sample_index <= '0;
        xadc_fault <= 1'b0;
    end else begin
        xadc_den <= 1'b0;
        sample_valid <= 1'b0;

        case (controller_state)
            WAIT_EOC: begin
                timeout_counter <= '0;

                if (xadc_drdy) begin
                    xadc_fault <= 1'b1;
                end

                if (xadc_eoc) begin
                    xadc_den <= 1'b1;
                    controller_state <= WAIT_DRDY;
                end
            end

            WAIT_DRDY: begin
                if (xadc_eoc) begin
                    xadc_fault <= 1'b1;
                end

                if (xadc_drdy) begin
                    sample_u12 <= xadc_do[15:4];
                    sample_index <= next_index;
                    next_index <= next_index + 1'b1;
                    sample_valid <= 1'b1;
                    timeout_counter <= '0;
                    controller_state <= WAIT_EOC;
                end else if (timeout_counter == TIMEOUT_CYCLES-1) begin
                    xadc_fault <= 1'b1;
                    timeout_counter <= '0;
                    controller_state <= WAIT_EOC;
                end else begin
                    timeout_counter <= timeout_counter + 1'b1;
                end
            end

            default: begin
                controller_state <= WAIT_EOC;
                timeout_counter <= '0;
                xadc_fault <= 1'b1;
            end
        endcase
    end
end

endmodule
