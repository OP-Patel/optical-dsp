module dc_removal #(
    parameter int unsigned K = 10,
    parameter int unsigned FRACTIONAL_BITS = 10
)(
    input logic clk,
    input logic rst,
    input logic in_valid,
    input logic [11:0] in_sample,
    input logic clear_estimate,
    input logic freeze_estimate,

    output logic out_valid,
    output logic signed [12:0] out_sample,
    output logic [11:0] dc_estimate_dbg,
    output logic estimate_fault
);

// The estimate is unsigned Q12.10 for the baseline parameters. The centered
// output uses the pre-update estimate and appears with out_valid one clock
// after in_valid. Output rounding is nearest with half cases away from zero.
// The estimator update uses a signed arithmetic shift, so negative division
// rounds toward negative infinity. Bounds saturate and set estimate_fault.

localparam int unsigned ESTIMATE_WIDTH = 12 + FRACTIONAL_BITS;
localparam int unsigned ERROR_WIDTH = ESTIMATE_WIDTH + 1;
localparam logic [ESTIMATE_WIDTH-1:0] MAX_ESTIMATE_FIXED = {
    12'hfff,
    {FRACTIONAL_BITS{1'b0}}
};
localparam logic signed [ERROR_WIDTH:0] OUTPUT_ROUND_BIAS =
    {{ERROR_WIDTH{1'b0}}, 1'b1} <<< (FRACTIONAL_BITS - 1);

logic [ESTIMATE_WIDTH-1:0] dc_estimate_fixed;
logic signed [ERROR_WIDTH-1:0] input_fixed;
logic signed [ERROR_WIDTH-1:0] estimate_fixed_signed;
logic signed [ERROR_WIDTH-1:0] error_fixed;
logic signed [ERROR_WIDTH-1:0] estimate_update;
logic signed [ERROR_WIDTH:0] estimate_next;
logic signed [ERROR_WIDTH:0] error_extended;
logic signed [ERROR_WIDTH:0] rounded_output_wide;
logic signed [12:0] centered_sample;
logic [ESTIMATE_WIDTH:0] estimate_debug_rounded;

always_comb begin
    input_fixed = $signed({1'b0, in_sample, {FRACTIONAL_BITS{1'b0}}});
    estimate_fixed_signed = $signed({1'b0, dc_estimate_fixed});
    error_fixed = input_fixed - estimate_fixed_signed;
    estimate_update = error_fixed >>> K;

    estimate_next =
        $signed({estimate_fixed_signed[ERROR_WIDTH-1], estimate_fixed_signed}) +
        $signed({estimate_update[ERROR_WIDTH-1], estimate_update});

    error_extended = $signed({error_fixed[ERROR_WIDTH-1], error_fixed});

    if (error_extended >= 0)
        rounded_output_wide =
            (error_extended + OUTPUT_ROUND_BIAS) >>> FRACTIONAL_BITS;
    else
        rounded_output_wide =
            -(((-error_extended) + OUTPUT_ROUND_BIAS) >>> FRACTIONAL_BITS);

    centered_sample = rounded_output_wide[12:0];

    estimate_debug_rounded =
        {1'b0, dc_estimate_fixed} +
        ({{ESTIMATE_WIDTH{1'b0}}, 1'b1} <<< (FRACTIONAL_BITS - 1));

    if ((estimate_debug_rounded >> FRACTIONAL_BITS) > 12'hfff)
        dc_estimate_dbg = 12'hfff;
    else
        dc_estimate_dbg = estimate_debug_rounded >> FRACTIONAL_BITS;
end

always_ff @(posedge clk) begin
    if (rst || clear_estimate) begin
        dc_estimate_fixed <= '0;
        out_valid <= 1'b0;
        out_sample <= '0;
        estimate_fault <= 1'b0;
    end else begin
        out_valid <= in_valid;

        if (in_valid) begin
            out_sample <= centered_sample;

            if (!freeze_estimate) begin
                if (estimate_next < 0) begin
                    dc_estimate_fixed <= '0;
                    estimate_fault <= 1'b1;
                end else if (estimate_next > $signed({1'b0, MAX_ESTIMATE_FIXED})) begin
                    dc_estimate_fixed <= MAX_ESTIMATE_FIXED;
                    estimate_fault <= 1'b1;
                end else begin
                    dc_estimate_fixed <= estimate_next[ESTIMATE_WIDTH-1:0];
                end
            end
        end
    end
end

endmodule
