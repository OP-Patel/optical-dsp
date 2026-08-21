module round_saturate #(
    parameter int unsigned INPUT_WIDTH = 34,
    parameter int unsigned OUTPUT_WIDTH = 16,
    parameter int unsigned SHIFT = 14
)(
    input logic signed [INPUT_WIDTH-1:0] in_value,

    output logic signed [OUTPUT_WIDTH-1:0] out_value,
    output logic saturated
);

localparam logic signed [OUTPUT_WIDTH-1:0] MAX_OUTPUT = {
    1'b0,
    {OUTPUT_WIDTH-1{1'b1}}
};
localparam logic signed [OUTPUT_WIDTH-1:0] MIN_OUTPUT = {
    1'b1,
    {OUTPUT_WIDTH-1{1'b0}}
};
localparam logic signed [INPUT_WIDTH:0] ROUND_BIAS =
    {{INPUT_WIDTH{1'b0}}, 1'b1} <<< (SHIFT - 1);
localparam logic signed [INPUT_WIDTH:0] NEGATIVE_ROUND_BIAS =
    ROUND_BIAS - 1'b1;
localparam logic signed [INPUT_WIDTH:0] MAX_OUTPUT_EXTENDED = {
    {(INPUT_WIDTH + 1 - OUTPUT_WIDTH){1'b0}},
    MAX_OUTPUT
};
localparam logic signed [INPUT_WIDTH:0] MIN_OUTPUT_EXTENDED = {
    {(INPUT_WIDTH + 1 - OUTPUT_WIDTH){1'b1}},
    MIN_OUTPUT
};

logic signed [INPUT_WIDTH:0] input_extended;
logic signed [INPUT_WIDTH:0] rounded_value;

always_comb begin
    input_extended = $signed({in_value[INPUT_WIDTH-1], in_value});

    if (input_extended >= 0)
        rounded_value = (input_extended + ROUND_BIAS) >>> SHIFT;
    else
        rounded_value = (input_extended + NEGATIVE_ROUND_BIAS) >>> SHIFT;

    saturated = 1'b0;

    if (rounded_value > MAX_OUTPUT_EXTENDED) begin
        out_value = MAX_OUTPUT;
        saturated = 1'b1;
    end else if (rounded_value < MIN_OUTPUT_EXTENDED) begin
        out_value = MIN_OUTPUT;
        saturated = 1'b1;
    end else begin
        out_value = rounded_value[OUTPUT_WIDTH-1:0];
    end
end

endmodule
