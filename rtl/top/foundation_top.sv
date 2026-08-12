module foundation_top (
    input logic clk_100mhz,
    input logic reset_btn,
    output logic heartbeat_led
);

    logic rst;

    reset_sync reset_sync_inst (
        .clk(clk_100mhz),
        .async_reset_in(reset_btn),
        .rst(rst)
    );

    heartbeat #(
        .DIVISOR(50_000_000)
    ) heartbeat_inst (
        .clk (clk_100mhz),
        .rst (rst),
        .led (heartbeat_led)
    );

endmodule