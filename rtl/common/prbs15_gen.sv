module prbs15_gen #(
    parameter logic [14:0] SEED = 15'h0001
) (
    input logic clk,
    input logic rst,
    input logic load_seed,
    input logic advance,
    output logic bit_out,
    output logic [14:0] state
);

logic feedback;

assign bit_out = state[14];
assign feedback = state[14] ^ state[13];

always_ff @(posedge clk) begin
    if (rst) begin
        state <= SEED;
    end else if (load_seed) begin
        state <= SEED;
    end else if (state == 15'b0) begin
        state <= SEED;
    end else if (advance) begin
        state <= {state[13:0], feedback};
    end
end

endmodule