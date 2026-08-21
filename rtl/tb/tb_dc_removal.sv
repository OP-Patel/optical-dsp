`timescale 1ns/1ps

module tb_dc_removal;

localparam time CLK_PERIOD = 10ns;
localparam int unsigned K = 10;
localparam int unsigned FRACTIONAL_BITS = 10;
localparam longint signed SCALE = 1 <<< FRACTIONAL_BITS;
localparam longint signed ROUND_BIAS = 1 <<< (FRACTIONAL_BITS - 1);

logic clk = 1'b0;
logic rst = 1'b1;
logic in_valid = 1'b0;
logic [11:0] in_sample = 12'b0;
logic clear_estimate = 1'b0;
logic freeze_estimate = 1'b0;
logic out_valid;
logic signed [12:0] out_sample;
logic [11:0] dc_estimate_dbg;
logic estimate_fault;

longint signed model_estimate = 0;
longint signed expected_output;
longint signed model_error;
longint signed model_update;
longint signed estimate_before_gap;
integer checks = 0;
integer preserved_positive = 0;
integer preserved_negative = 0;

dc_removal #(
    .K(K),
    .FRACTIONAL_BITS(FRACTIONAL_BITS)
) dut(
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .in_sample(in_sample),
    .clear_estimate(clear_estimate),
    .freeze_estimate(freeze_estimate),
    .out_valid(out_valid),
    .out_sample(out_sample),
    .dc_estimate_dbg(dc_estimate_dbg),
    .estimate_fault(estimate_fault)
);

always #(CLK_PERIOD / 2) clk = ~clk;

function automatic longint signed round_centered(
    input longint signed fixed_value
);
begin
    if (fixed_value >= 0)
        round_centered = (fixed_value + ROUND_BIAS) >>> FRACTIONAL_BITS;
    else
        round_centered = -(((-fixed_value) + ROUND_BIAS) >>> FRACTIONAL_BITS);
end
endfunction

function automatic integer rounded_estimate(
    input longint signed fixed_value
);
    longint signed rounded_value;
begin
    rounded_value = (fixed_value + ROUND_BIAS) >>> FRACTIONAL_BITS;

    if (rounded_value < 0)
        rounded_estimate = 0;
    else if (rounded_value > 4095)
        rounded_estimate = 4095;
    else
        rounded_estimate = rounded_value;
end
endfunction

task automatic apply_cycle(
    input logic valid_value,
    input logic [11:0] sample_value,
    input logic clear_value,
    input logic freeze_value
);
begin
    @(negedge clk);
    in_valid = valid_value;
    in_sample = sample_value;
    clear_estimate = clear_value;
    freeze_estimate = freeze_value;

    if (clear_value) begin
        expected_output = 0;
    end else begin
        model_error = (longint'(sample_value) * SCALE) - model_estimate;
        expected_output = round_centered(model_error);
        model_update = model_error >>> K;
    end

    @(posedge clk);
    #1ns;

    if (clear_value) begin
        model_estimate = 0;
        assert (!out_valid && out_sample == 0 && dc_estimate_dbg == 0)
        else $fatal(1, "clear did not reset the complete filter state");
        checks += 3;
    end else begin
        assert (out_valid == valid_value)
        else $fatal(1, "out_valid latency mismatch valid=%0b", valid_value);
        checks++;

        if (valid_value) begin
            assert ($signed(out_sample) == expected_output)
            else $fatal(
                1,
                "output mismatch sample=%0d expected=%0d actual=%0d estimate=%0d",
                sample_value,
                expected_output,
                $signed(out_sample),
                model_estimate
            );
            checks++;

            if (!freeze_value)
                model_estimate = model_estimate + model_update;
        end

        assert (dc_estimate_dbg == rounded_estimate(model_estimate))
        else $fatal(
            1,
            "estimate mismatch expected=%0d actual=%0d fixed=%0d",
            rounded_estimate(model_estimate),
            dc_estimate_dbg,
            model_estimate
        );
        checks++;
    end

    assert (!estimate_fault)
    else $fatal(1, "legal 12-bit sequence raised estimate_fault");
    checks++;
end
endtask

task automatic clear_filter;
begin
    apply_cycle(1'b0, 12'b0, 1'b1, 1'b0);
    apply_cycle(1'b0, 12'b0, 1'b0, 1'b0);
end
endtask

initial begin
    repeat (3) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;

    // Constant zero is unchanged and idle clocks cannot update the estimate.
    repeat (8)
        apply_cycle(1'b1, 12'd0, 1'b0, 1'b0);

    estimate_before_gap = model_estimate;
    repeat (12)
        apply_cycle(1'b0, $urandom_range(0, 4095), 1'b0, 1'b0);
    assert (model_estimate == estimate_before_gap)
    else $fatal(1, "invalid clocks changed the reference estimate");
    checks++;

    // A constant midscale input settles to within one output code.
    clear_filter();
    repeat (9000)
        apply_cycle(1'b1, 12'd2048, 1'b0, 1'b0);
    assert (($signed(out_sample) >= -1) && ($signed(out_sample) <= 1))
    else $fatal(1, "constant midscale did not settle near zero");
    checks++;

    // Step response is checked bit for bit before and after the transition.
    clear_filter();
    repeat (3200)
        apply_cycle(1'b1, 12'd1000, 1'b0, 1'b0);
    repeat (3200)
        apply_cycle(1'b1, 12'd3000, 1'b0, 1'b0);

    // The balanced fast pattern must retain both polarities after warm-up.
    clear_filter();
    repeat (5000) begin
        apply_cycle(1'b1, 12'd1000, 1'b0, 1'b0);
        apply_cycle(1'b1, 12'd3000, 1'b0, 1'b0);
    end

    repeat (128) begin
        apply_cycle(1'b1, 12'd1000, 1'b0, 1'b0);
        if ($signed(out_sample) < -900)
            preserved_negative++;

        apply_cycle(1'b1, 12'd3000, 1'b0, 1'b0);
        if ($signed(out_sample) > 900)
            preserved_positive++;
    end

    assert (preserved_negative == 128 && preserved_positive == 128)
    else $fatal(1, "alternating pattern was not preserved around zero");
    checks++;

    // Freeze holds the estimate while output samples continue normally.
    estimate_before_gap = model_estimate;
    repeat (32)
        apply_cycle(1'b1, 12'd4095, 1'b0, 1'b1);
    assert (model_estimate == estimate_before_gap)
    else $fatal(1, "freeze changed the estimate");
    checks++;

    // Slow ramp and randomized valid gaps exercise sample-enable behavior.
    clear_filter();
    for (int ramp_value = 0; ramp_value <= 4095; ramp_value += 17) begin
        apply_cycle(1'b1, ramp_value[11:0], 1'b0, 1'b0);
        repeat ($urandom_range(0, 3))
            apply_cycle(1'b0, $urandom_range(0, 4095), 1'b0, 1'b0);
    end

    // Full-range alternating extremes prove the signed output never wraps.
    clear_filter();
    repeat (2048) begin
        apply_cycle(1'b1, 12'd0, 1'b0, 1'b0);
        assert ($signed(out_sample) >= -4095 && $signed(out_sample) <= 4095)
        else $fatal(1, "minimum-code output wrapped");
        checks++;

        apply_cycle(1'b1, 12'd4095, 1'b0, 1'b0);
        assert ($signed(out_sample) >= -4095 && $signed(out_sample) <= 4095)
        else $fatal(1, "maximum-code output wrapped");
        checks++;
    end

    $display(
        "PASS: tb_dc_removal checks=%0d K=%0d fractional_bits=%0d",
        checks,
        K,
        FRACTIONAL_BITS
    );
    $finish;
end

initial begin
    #2ms;
    $fatal(1, "tb_dc_removal timed out");
end

endmodule
