module fir_filter #(
    parameter int unsigned TAPS = 16
)(
    input logic clk,
    input logic rst,
    input logic clear_history,
    input logic in_valid,
    input logic signed [12:0] in_sample,
    input logic filter_enable,
    input logic [1:0] coeff_bank,

    output logic out_valid,
    output logic signed [15:0] out_sample,
    output logic saturation_pulse,
    output logic [1:0] active_coeff_bank
);

import fir_coefficients_pkg::*;

localparam int unsigned INPUT_WIDTH = 13;
localparam int unsigned COEFFICIENT_WIDTH = 16;
localparam int unsigned PRODUCT_WIDTH = INPUT_WIDTH + COEFFICIENT_WIDTH;
localparam int unsigned ACCUMULATOR_WIDTH = 34;
localparam int unsigned COEFFICIENT_FRACTIONAL_BITS = 14;
localparam int unsigned TREE_LEVELS = $clog2(TAPS);

logic signed [INPUT_WIDTH-1:0] sample_delay [0:TAPS-2];
logic signed [PRODUCT_WIDTH-1:0] product_comb [0:TAPS-1];
logic signed [PRODUCT_WIDTH-1:0] product_pipeline [0:TAPS-1];
logic signed [ACCUMULATOR_WIDTH-1:0] sum_pipeline [0:TREE_LEVELS-1][0:TAPS-1];
logic signed [ACCUMULATOR_WIDTH-1:0] accumulator;
logic signed [15:0] rounded_sample;
logic accumulator_saturated;
logic signed [15:0] bypass_sample;
logic signed [15:0] bypass_pipeline;
logic signed [15:0] bypass_sum_pipeline [0:TREE_LEVELS-1];
logic product_valid;
logic filter_enable_pipeline;
logic filter_enable_sum_pipeline [0:TREE_LEVELS-1];
logic [TREE_LEVELS-1:0] sum_valid_pipeline;

always_comb begin
    for (int tap = 0; tap < TAPS; tap++) begin
        if (tap == 0)
            product_comb[tap] =
                $signed(in_sample) *
                $signed(fir_coefficient(active_coeff_bank, tap, TAPS));
        else
            product_comb[tap] =
                $signed(sample_delay[tap - 1]) *
                $signed(fir_coefficient(active_coeff_bank, tap, TAPS));
    end

    bypass_sample = $signed({{3{in_sample[12]}}, in_sample});

    accumulator = sum_pipeline[TREE_LEVELS - 1][0];
end

round_saturate #(
    .INPUT_WIDTH(ACCUMULATOR_WIDTH),
    .OUTPUT_WIDTH(16),
    .SHIFT(COEFFICIENT_FRACTIONAL_BITS)
) output_round_saturate_inst(
    .in_value(accumulator),
    .out_value(rounded_sample),
    .saturated(accumulator_saturated)
);

always_ff @(posedge clk) begin
    if (rst) begin
        for (int tap = 0; tap < TAPS - 1; tap++)
            sample_delay[tap] <= '0;
        for (int tap = 0; tap < TAPS; tap++)
            product_pipeline[tap] <= '0;
        for (int level = 0; level < TREE_LEVELS; level++) begin
            bypass_sum_pipeline[level] <= '0;
            filter_enable_sum_pipeline[level] <= 1'b0;

            for (int node = 0; node < TAPS; node++)
                sum_pipeline[level][node] <= '0;
        end

        active_coeff_bank <= coeff_bank;
        product_valid <= 1'b0;
        sum_valid_pipeline <= '0;
        filter_enable_pipeline <= 1'b0;
        bypass_pipeline <= '0;
        out_valid <= 1'b0;
        out_sample <= '0;
        saturation_pulse <= 1'b0;
    end else if (clear_history) begin
        for (int tap = 0; tap < TAPS - 1; tap++)
            sample_delay[tap] <= '0;
        for (int tap = 0; tap < TAPS; tap++)
            product_pipeline[tap] <= '0;
        for (int level = 0; level < TREE_LEVELS; level++) begin
            bypass_sum_pipeline[level] <= '0;
            filter_enable_sum_pipeline[level] <= 1'b0;

            for (int node = 0; node < TAPS; node++)
                sum_pipeline[level][node] <= '0;
        end

        active_coeff_bank <= coeff_bank;
        product_valid <= 1'b0;
        sum_valid_pipeline <= '0;
        filter_enable_pipeline <= 1'b0;
        bypass_pipeline <= '0;
        out_valid <= 1'b0;
        out_sample <= '0;
        saturation_pulse <= 1'b0;
    end else begin
        out_valid <= sum_valid_pipeline[TREE_LEVELS - 1];
        saturation_pulse <= 1'b0;

        if (sum_valid_pipeline[TREE_LEVELS - 1]) begin
            if (filter_enable_sum_pipeline[TREE_LEVELS - 1]) begin
                out_sample <= rounded_sample;
                saturation_pulse <= accumulator_saturated;
            end else begin
                out_sample <= bypass_sum_pipeline[TREE_LEVELS - 1];
            end
        end

        product_valid <= in_valid;
        sum_valid_pipeline[0] <= product_valid;
        bypass_sum_pipeline[0] <= bypass_pipeline;
        filter_enable_sum_pipeline[0] <= filter_enable_pipeline;

        for (int node = 0; node < TAPS; node++) begin
            if (node < (TAPS >> 1)) begin
                sum_pipeline[0][node] <=
                    $signed({
                        {(ACCUMULATOR_WIDTH - PRODUCT_WIDTH){product_pipeline[node * 2][PRODUCT_WIDTH-1]}},
                        product_pipeline[node * 2]
                    }) +
                    $signed({
                        {(ACCUMULATOR_WIDTH - PRODUCT_WIDTH){product_pipeline[(node * 2) + 1][PRODUCT_WIDTH-1]}},
                        product_pipeline[(node * 2) + 1]
                    });
            end else begin
                sum_pipeline[0][node] <= '0;
            end
        end

        for (int level = 1; level < TREE_LEVELS; level++) begin
            sum_valid_pipeline[level] <= sum_valid_pipeline[level - 1];
            bypass_sum_pipeline[level] <= bypass_sum_pipeline[level - 1];
            filter_enable_sum_pipeline[level] <= filter_enable_sum_pipeline[level - 1];

            for (int node = 0; node < TAPS; node++) begin
                if (node < (TAPS >> (level + 1)))
                    sum_pipeline[level][node] <=
                        sum_pipeline[level - 1][node * 2] +
                        sum_pipeline[level - 1][(node * 2) + 1];
                else
                    sum_pipeline[level][node] <= '0;
            end
        end

        if (in_valid) begin
            for (int tap = TAPS - 2; tap > 0; tap--)
                sample_delay[tap] <= sample_delay[tap - 1];

            sample_delay[0] <= in_sample;
            for (int tap = 0; tap < TAPS; tap++)
                product_pipeline[tap] <= product_comb[tap];

            filter_enable_pipeline <= filter_enable;
            bypass_pipeline <= bypass_sample;
        end
    end
end

endmodule
