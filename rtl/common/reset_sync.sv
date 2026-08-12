module reset_sync(
    input logic clk, 
    input logic async_reset_in,
    output logic rst
);

logic rst1, rst2; 

always_ff@(posedge clk or posedge async_reset_in) begin
    if(async_reset_in) begin // if we drive a 1 on async_reset_in, we force-drive the reset output to 1 -> asynchronous assert
        rst1 <= 1'b1; 
        rst2 <= 1'b1; 
    end else begin // if we drive a 0 on async_reset_in, we let the reset output go to 0 after 2 clock cycles -> synchronous deassert
        rst1 <= 1'b0; 
        rst2 <= rst1; 
    end
end

assign rst = rst2; 

endmodule