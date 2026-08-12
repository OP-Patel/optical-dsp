module clock_enable_gen#
( 
    parameter int unsigned DIVISOR = 4
)
(
    input logic clk, 
    input logic rst,
    output logic enable
);

localparam int COUNTER_WIDTH = (DIVISOR <= 1) ? 1 : $clog2(DIVISOR); // size the counter based on the divisor value, but we cant have <1 or $clog2 == 0

logic [COUNTER_WIDTH-1:0] counter;

always_ff@(posedge clk or posedge rst) begin 
    if(rst) begin
        counter <= 1'b0;
        enable <= 1'b0;
    end else if(counter == DIVISOR-1) begin
        counter <= 1'b0;
        enable <= 1'b1;
    end else begin 
        counter <= counter + 1'b1; // increment the counter
        enable <= 1'b0;
    end 
end

endmodule
