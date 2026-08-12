module prbs15_check (
    input  logic clk,
    input  logic rst,
    input  logic load_seed,
    input  logic bit_valid,
    input  logic bit_in,
    output logic error_pulse
);

logic expected_bit;
logic [14:0] expected_state;

prbs15_gen expected_generator (
    .clk(clk),
    .rst(rst),
    .load_seed(load_seed),
    .advance(bit_valid && !load_seed),
    .bit_out(expected_bit),
    .state(expected_state)
);

always_ff @(posedge clk) begin
    if (rst) begin
        error_pulse <= 1'b0;
    end else if (load_seed) begin
        error_pulse <= 1'b0;
    end else begin
        error_pulse <= bit_valid && (bit_in != expected_bit);
    end
end

endmodule