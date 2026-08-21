`timescale 1ns/1ps

module tb_fir_filter;

localparam time CLK_PERIOD = 10ns;
localparam int unsigned FRACTIONAL_BITS = 14;
localparam longint signed ROUND_BIAS = 1 <<< (FRACTIONAL_BITS - 1);

logic clk = 1'b0;
logic rst = 1'b1;
logic clear_history = 1'b0;
logic in_valid = 1'b0;
logic signed [12:0] in_sample = '0;
logic filter_enable = 1'b1;
logic [1:0] coeff_bank = 2'b00;

logic out_valid_8;
logic signed [15:0] out_sample_8;
logic saturation_pulse_8;
logic [1:0] active_coeff_bank_8;
logic out_valid_16;
logic signed [15:0] out_sample_16;
logic saturation_pulse_16;
logic [1:0] active_coeff_bank_16;

longint signed model_delay_8 [0:6];
longint signed model_delay_16 [0:14];
integer model_bank_8 = 0;
integer model_bank_16 = 0;
longint signed accumulator_8;
longint signed accumulator_16;
longint signed expected_sample_8;
longint signed expected_sample_16;
logic expected_saturation_8;
logic expected_saturation_16;
logic pending_valid_8 [0:3];
logic pending_valid_16 [0:4];
longint signed pending_sample_8 [0:3];
longint signed pending_sample_16 [0:4];
logic pending_saturation_8 [0:3];
logic pending_saturation_16 [0:4];
integer checks = 0;
integer random_seed = 32'h10f17e5a;

fir_filter #(
    .TAPS(8)
) dut_8(
    .clk(clk),
    .rst(rst),
    .clear_history(clear_history),
    .in_valid(in_valid),
    .in_sample(in_sample),
    .filter_enable(filter_enable),
    .coeff_bank(coeff_bank),
    .out_valid(out_valid_8),
    .out_sample(out_sample_8),
    .saturation_pulse(saturation_pulse_8),
    .active_coeff_bank(active_coeff_bank_8)
);

fir_filter #(
    .TAPS(16)
) dut_16(
    .clk(clk),
    .rst(rst),
    .clear_history(clear_history),
    .in_valid(in_valid),
    .in_sample(in_sample),
    .filter_enable(filter_enable),
    .coeff_bank(coeff_bank),
    .out_valid(out_valid_16),
    .out_sample(out_sample_16),
    .saturation_pulse(saturation_pulse_16),
    .active_coeff_bank(active_coeff_bank_16)
);

always #(CLK_PERIOD / 2) clk = ~clk;

function automatic longint signed coefficient_reference(
    input integer bank,
    input integer tap,
    input integer taps
);
begin
    case (bank)
        0: coefficient_reference = tap == 0 ? 16384 : 0;
        1: coefficient_reference = tap < 4 ? 4096 : 0;
        2: coefficient_reference = tap < taps ? 16384 / taps : 0;
        3: coefficient_reference = 32767;
        default: coefficient_reference = 0;
    endcase
end
endfunction

function automatic longint signed round_reference(
    input longint signed fixed_value
);
begin
    if (fixed_value >= 0)
        round_reference = (fixed_value + ROUND_BIAS) >>> FRACTIONAL_BITS;
    else
        round_reference = -(((-fixed_value) + ROUND_BIAS) >>> FRACTIONAL_BITS);
end
endfunction

task automatic limit_reference(
    input longint signed rounded_value,
    output longint signed limited_value,
    output logic was_saturated
);
begin
    was_saturated = 1'b0;

    if (rounded_value > 32767) begin
        limited_value = 32767;
        was_saturated = 1'b1;
    end else if (rounded_value < -32768) begin
        limited_value = -32768;
        was_saturated = 1'b1;
    end else begin
        limited_value = rounded_value;
    end
end
endtask

task automatic apply_cycle(
    input logic valid_value,
    input longint signed sample_value,
    input logic clear_value,
    input logic enable_value,
    input logic [1:0] bank_value
);
    longint signed rounded_8;
    longint signed rounded_16;
begin
    @(negedge clk);
    in_valid = valid_value;
    in_sample = sample_value;
    clear_history = clear_value;
    filter_enable = enable_value;
    coeff_bank = bank_value;

    accumulator_8 = sample_value * coefficient_reference(model_bank_8, 0, 8);
    for (int tap = 1; tap < 8; tap++)
        accumulator_8 = accumulator_8 +
            model_delay_8[tap - 1] * coefficient_reference(model_bank_8, tap, 8);

    accumulator_16 = sample_value * coefficient_reference(model_bank_16, 0, 16);
    for (int tap = 1; tap < 16; tap++)
        accumulator_16 = accumulator_16 +
            model_delay_16[tap - 1] * coefficient_reference(model_bank_16, tap, 16);

    rounded_8 = round_reference(accumulator_8);
    rounded_16 = round_reference(accumulator_16);
    limit_reference(rounded_8, expected_sample_8, expected_saturation_8);
    limit_reference(rounded_16, expected_sample_16, expected_saturation_16);

    if (!enable_value) begin
        expected_sample_8 = sample_value;
        expected_sample_16 = sample_value;
        expected_saturation_8 = 1'b0;
        expected_saturation_16 = 1'b0;
    end

    @(posedge clk);
    #1ns;

    if (clear_value) begin
        assert (!out_valid_8 && !out_valid_16)
        else $fatal(1, "clear did not suppress output valid");
        assert (out_sample_8 == 0 && out_sample_16 == 0)
        else $fatal(1, "clear did not clear outputs");
        assert (active_coeff_bank_8 == bank_value && active_coeff_bank_16 == bank_value)
        else $fatal(1, "clear did not latch the requested coefficient bank");
        checks += 6;

        model_bank_8 = bank_value;
        model_bank_16 = bank_value;
        for (int stage = 0; stage < 4; stage++) begin
            pending_valid_8[stage] = 1'b0;
            pending_sample_8[stage] = 0;
            pending_saturation_8[stage] = 1'b0;
        end
        for (int stage = 0; stage < 5; stage++) begin
            pending_valid_16[stage] = 1'b0;
            pending_sample_16[stage] = 0;
            pending_saturation_16[stage] = 1'b0;
        end
        for (int tap = 0; tap < 7; tap++)
            model_delay_8[tap] = 0;
        for (int tap = 0; tap < 15; tap++)
            model_delay_16[tap] = 0;
    end else begin
        assert (out_valid_8 == pending_valid_8[3])
        else $fatal(1, "8-tap five-stage valid latency mismatch");
        assert (out_valid_16 == pending_valid_16[4])
        else $fatal(1, "16-tap six-stage valid latency mismatch");
        checks += 2;

        if (pending_valid_8[3]) begin
            assert ($signed(out_sample_8) == pending_sample_8[3])
            else $fatal(
                1,
                "8-tap mismatch expected=%0d actual=%0d accumulator=%0d",
                pending_sample_8[3],
                $signed(out_sample_8),
                accumulator_8
            );
            assert (saturation_pulse_8 == pending_saturation_8[3])
            else $fatal(1, "8-tap saturation pulse mismatch");
            checks += 2;
        end else begin
            assert (!saturation_pulse_8)
            else $fatal(1, "invalid 8-tap result produced a saturation pulse");
            checks++;
        end

        if (pending_valid_16[4]) begin
            assert ($signed(out_sample_16) == pending_sample_16[4])
            else $fatal(
                1,
                "16-tap mismatch expected=%0d actual=%0d accumulator=%0d",
                pending_sample_16[4],
                $signed(out_sample_16),
                accumulator_16
            );
            assert (saturation_pulse_16 == pending_saturation_16[4])
            else $fatal(1, "16-tap saturation pulse mismatch");
            checks += 2;
        end else begin
            assert (!saturation_pulse_16)
            else $fatal(1, "invalid 16-tap result produced a saturation pulse");
            checks++;
        end

        for (int stage = 3; stage > 0; stage--) begin
            pending_valid_8[stage] = pending_valid_8[stage - 1];
            pending_sample_8[stage] = pending_sample_8[stage - 1];
            pending_saturation_8[stage] = pending_saturation_8[stage - 1];
        end
        pending_valid_8[0] = valid_value;
        pending_sample_8[0] = expected_sample_8;
        pending_saturation_8[0] = expected_saturation_8;

        for (int stage = 4; stage > 0; stage--) begin
            pending_valid_16[stage] = pending_valid_16[stage - 1];
            pending_sample_16[stage] = pending_sample_16[stage - 1];
            pending_saturation_16[stage] = pending_saturation_16[stage - 1];
        end
        pending_valid_16[0] = valid_value;
        pending_sample_16[0] = expected_sample_16;
        pending_saturation_16[0] = expected_saturation_16;

        if (valid_value) begin
            for (int tap = 6; tap > 0; tap--)
                model_delay_8[tap] = model_delay_8[tap - 1];
            model_delay_8[0] = sample_value;

            for (int tap = 14; tap > 0; tap--)
                model_delay_16[tap] = model_delay_16[tap - 1];
            model_delay_16[0] = sample_value;
        end

        assert (active_coeff_bank_8 == model_bank_8)
        else $fatal(1, "8-tap bank changed without clear");
        assert (active_coeff_bank_16 == model_bank_16)
        else $fatal(1, "16-tap bank changed without clear");
        checks += 2;
    end
end
endtask

task automatic select_bank(input logic [1:0] bank_value);
begin
    apply_cycle(1'b0, 0, 1'b1, 1'b1, bank_value);
    apply_cycle(1'b0, 0, 1'b0, 1'b1, bank_value);
end
endtask

initial begin
    for (int tap = 0; tap < 7; tap++)
        model_delay_8[tap] = 0;
    for (int tap = 0; tap < 15; tap++)
        model_delay_16[tap] = 0;

    repeat (3) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;

    // Identity is exact, including bypass and its matching pipeline latency.
    select_bank(2'b00);
    apply_cycle(1'b1, 4095, 1'b0, 1'b1, 2'b00);
    repeat (6)
        apply_cycle(1'b0, 0, 1'b0, 1'b1, 2'b00);
    assert ($signed(out_sample_8) == 4095 && $signed(out_sample_16) == 4095)
    else $fatal(1, "identity bank was not exact");
    checks += 2;
    apply_cycle(1'b1, -1234, 1'b0, 1'b0, 2'b00);
    repeat (6)
        apply_cycle(1'b0, 0, 1'b0, 1'b0, 2'b00);
    assert ($signed(out_sample_8) == -1234 && $signed(out_sample_16) == -1234)
    else $fatal(1, "latency-matched bypass was not exact");
    checks += 2;

    // Four-sample average impulse response is 1024 for four outputs.
    select_bank(2'b01);
    for (int response_index = 0; response_index < 24; response_index++)
        apply_cycle(1'b1, response_index == 0 ? 4095 : 0, 1'b0, 1'b1, 2'b01);

    // Full averages have eight 512-code or sixteen 256-code impulse outputs.
    select_bank(2'b10);
    for (int response_index = 0; response_index < 32; response_index++)
        apply_cycle(1'b1, response_index == 0 ? 4095 : 0, 1'b0, 1'b1, 2'b10);

    // A normalized constant settles back to the same value.
    repeat (30)
        apply_cycle(1'b1, 1000, 1'b0, 1'b1, 2'b10);
    assert ($signed(out_sample_8) == 1000 && $signed(out_sample_16) == 1000)
    else $fatal(1, "normalized constant gain was not one");
    checks += 2;

    // A bank input change is ignored until clear_history is asserted.
    repeat (4)
        apply_cycle(1'b1, 2000, 1'b0, 1'b1, 2'b00);
    assert (active_coeff_bank_8 == 2'b10 && active_coeff_bank_16 == 2'b10)
    else $fatal(1, "coefficient bank changed outside safe boundary");
    checks += 2;

    // Hand vector, alternating extremes, gaps, and deterministic random data.
    select_bank(2'b01);
    apply_cycle(1'b1, 100, 1'b0, 1'b1, 2'b01);
    apply_cycle(1'b1, -200, 1'b0, 1'b1, 2'b01);
    apply_cycle(1'b1, 300, 1'b0, 1'b1, 2'b01);
    apply_cycle(1'b1, -400, 1'b0, 1'b1, 2'b01);
    repeat (6)
        apply_cycle(1'b0, 0, 1'b0, 1'b1, 2'b01);
    assert ($signed(out_sample_8) == -50 && $signed(out_sample_16) == -50)
    else $fatal(1, "hand-calculated vector failed");
    checks += 2;

    repeat (64) begin
        apply_cycle(1'b1, 4095, 1'b0, 1'b1, 2'b01);
        apply_cycle(1'b0, $urandom(random_seed) % 4096, 1'b0, 1'b1, 2'b01);
        apply_cycle(1'b1, -4095, 1'b0, 1'b1, 2'b01);
    end

    repeat (500) begin
        if (($urandom(random_seed) % 4) == 0)
            apply_cycle(1'b0, $urandom(random_seed) % 4096, 1'b0, 1'b1, 2'b01);
        else
            apply_cycle(
                1'b1,
                ($urandom(random_seed) % 8191) - 4095,
                1'b0,
                1'b1,
                2'b01
            );
    end

    // Diagnostic bank deliberately exceeds both output limits.
    select_bank(2'b11);
    repeat (20)
        apply_cycle(1'b1, 4095, 1'b0, 1'b1, 2'b11);
    assert (saturation_pulse_8 && saturation_pulse_16)
    else $fatal(1, "positive saturation was not reported");
    checks += 2;

    select_bank(2'b11);
    repeat (20)
        apply_cycle(1'b1, -4095, 1'b0, 1'b1, 2'b11);
    assert (saturation_pulse_8 && saturation_pulse_16)
    else $fatal(1, "negative saturation was not reported");
    checks += 2;

    repeat (6)
        apply_cycle(1'b0, 0, 1'b0, 1'b1, 2'b11);
    assert (!saturation_pulse_8 && !saturation_pulse_16)
    else $fatal(1, "saturation pulse did not clear");
    checks += 2;

    $display("PASS: tb_fir_filter checks=%0d tap_variants=8,16", checks);
    $finish;
end

initial begin
    #2ms;
    $fatal(1, "tb_fir_filter timed out");
end

endmodule
