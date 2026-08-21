module fir_variant_benchmark_top #(
    parameter int unsigned TAPS = 8
)(
    input logic clk_100mhz,
    input logic reset_btn,

    output logic filter_activity_led,
    output logic filter_saturation_led
);

logic rst;
logic [12:0] sample_counter;
logic signed [12:0] test_sample;
logic out_valid;
logic signed [15:0] out_sample;
logic saturation_pulse;
logic [1:0] active_coeff_bank;

reset_sync reset_sync_inst(
    .clk(clk_100mhz),
    .async_reset_in(reset_btn),
    .rst(rst)
);

always_ff @(posedge clk_100mhz) begin
    if (rst)
        sample_counter <= 13'b0;
    else
        sample_counter <= sample_counter + 1'b1;
end

assign test_sample = $signed(sample_counter);
assign filter_activity_led = out_valid && ^out_sample;
assign filter_saturation_led = saturation_pulse;

fir_filter #(
    .TAPS(TAPS)
) fir_filter_inst(
    .clk(clk_100mhz),
    .rst(rst),
    .clear_history(1'b0),
    .in_valid(1'b1),
    .in_sample(test_sample),
    .filter_enable(1'b1),
    .coeff_bank(2'b10),
    .out_valid(out_valid),
    .out_sample(out_sample),
    .saturation_pulse(saturation_pulse),
    .active_coeff_bank(active_coeff_bank)
);

endmodule
