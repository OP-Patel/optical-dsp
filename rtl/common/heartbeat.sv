module heartbeat #(
    parameter int unsigned DIVISOR = 50_000_000
) (
    input  logic clk,
    input  logic rst,
    output logic led
);

    logic enable;

    clock_enable_gen #(
        .DIVISOR(DIVISOR)
    ) heartbeat_gen (
        .clk(clk),
        .rst(rst),
        .enable (enable)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            led <= 1'b0;
        else if (enable)
            led <= ~led;
    end

endmodule