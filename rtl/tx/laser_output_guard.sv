module laser_output_guard(
    input logic rst, 
    input logic tx_bit,
    input logic tx_enable,

    output logic fault, 
    output logic laser_drive
);

always_comb begin 
    fault = ~rst & ~tx_enable & tx_bit;
    laser_drive = ~rst & tx_enable & tx_bit; // routed to KY-008 S pin
end


endmodule
