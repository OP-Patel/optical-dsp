`timescale 1ns/1ps

module tb_round_saturate;

localparam int unsigned SHIFT = 14;

logic signed [33:0] in_value = '0;
logic signed [15:0] out_value;
logic saturated;
integer checks = 0;

round_saturate #(
    .INPUT_WIDTH(34),
    .OUTPUT_WIDTH(16),
    .SHIFT(SHIFT)
) dut(
    .in_value(in_value),
    .out_value(out_value),
    .saturated(saturated)
);

task automatic check_value(
    input longint signed input_value,
    input integer expected_value,
    input logic expected_saturated
);
begin
    in_value = input_value;
    #1ns;

    assert ($signed(out_value) == expected_value)
    else $fatal(
        1,
        "round result mismatch input=%0d expected=%0d actual=%0d",
        input_value,
        expected_value,
        $signed(out_value)
    );
    assert (saturated == expected_saturated)
    else $fatal(
        1,
        "saturation mismatch input=%0d expected=%0b actual=%0b",
        input_value,
        expected_saturated,
        saturated
    );
    checks += 2;
end
endtask

initial begin
    check_value(0, 0, 1'b0);
    check_value((1 <<< (SHIFT - 1)) - 1, 0, 1'b0);
    check_value(1 <<< (SHIFT - 1), 1, 1'b0);
    check_value((1 <<< SHIFT) + (1 <<< (SHIFT - 1)), 2, 1'b0);
    check_value(-((1 <<< (SHIFT - 1)) - 1), 0, 1'b0);
    check_value(-(1 <<< (SHIFT - 1)), -1, 1'b0);
    check_value(-((1 <<< SHIFT) + (1 <<< (SHIFT - 1))), -2, 1'b0);

    check_value(32767 <<< SHIFT, 32767, 1'b0);
    check_value((32767 <<< SHIFT) + (1 <<< (SHIFT - 1)) - 1, 32767, 1'b0);
    check_value((32767 <<< SHIFT) + (1 <<< (SHIFT - 1)), 32767, 1'b1);
    check_value(32768 <<< SHIFT, 32767, 1'b1);

    check_value(-32768 <<< SHIFT, -32768, 1'b0);
    check_value((-32768 <<< SHIFT) - (1 <<< (SHIFT - 1)) + 1, -32768, 1'b0);
    check_value((-32768 <<< SHIFT) - (1 <<< (SHIFT - 1)), -32768, 1'b1);
    check_value(-32769 <<< SHIFT, -32768, 1'b1);

    $display("PASS: tb_round_saturate checks=%0d", checks);
    $finish;
end

endmodule
