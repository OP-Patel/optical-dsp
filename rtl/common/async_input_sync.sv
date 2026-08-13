module async_input_sync(
    input logic clk,
    input logic rst,
    input logic async_in,
    output logic sync_out
);

logic sync_meta;

always_ff @(posedge clk) begin
    if (rst) begin
        sync_meta <= 1'b0;
        sync_out <= 1'b0;
    end else begin
        sync_meta <= async_in;
        sync_out <= sync_meta;
    end
end

endmodule
