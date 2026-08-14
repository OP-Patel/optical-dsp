module xadc_model(
    input logic clk,
    input logic rst,
    input logic model_conversion_valid,
    input logic [11:0] model_code,
    input logic [7:0] response_delay,
    input logic stall_drdy,
    input logic drp_den,
    input logic [6:0] drp_daddr,

    output logic xadc_eoc,
    output logic xadc_drdy,
    output logic [15:0] xadc_do,
    output logic model_busy,
    output logic model_protocol_error
);

localparam logic [6:0] VAUX4_ADDRESS = 7'h14;

logic [11:0] stored_code;
logic result_available;
logic read_pending;
logic [7:0] delay_counter;

assign model_busy = read_pending;

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        stored_code <= 12'b0;
        result_available <= 1'b0;
        read_pending <= 1'b0;
        delay_counter <= 8'b0;
        xadc_eoc <= 1'b0;
        xadc_drdy <= 1'b0;
        xadc_do <= 16'b0;
        model_protocol_error <= 1'b0;
    end else begin
        xadc_eoc <= 1'b0;
        xadc_drdy <= 1'b0;

        if (model_conversion_valid) begin
            stored_code <= model_code;
            result_available <= 1'b1;
            xadc_eoc <= 1'b1;
        end

        if (drp_den) begin
            if (drp_daddr != VAUX4_ADDRESS || read_pending || !result_available) begin
                model_protocol_error <= 1'b1;
            end else if (response_delay == 0 && !stall_drdy) begin
                xadc_do <= {stored_code, 4'b0};
                xadc_drdy <= 1'b1;
                result_available <= 1'b0;
            end else begin
                read_pending <= 1'b1;
                delay_counter <= response_delay;
            end
        end

        if (read_pending && !stall_drdy) begin
            if (delay_counter <= 1) begin
                xadc_do <= {stored_code, 4'b0};
                xadc_drdy <= 1'b1;
                result_available <= 1'b0;
                read_pending <= 1'b0;
                delay_counter <= 8'b0;
            end else begin
                delay_counter <= delay_counter - 1'b1;
            end
        end
    end
end

endmodule
