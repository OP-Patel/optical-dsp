module xadc_single_channel(
    input logic clk,
    input logic rst,
    input logic vaux4_p,
    input logic vaux4_n,
    input logic drp_den,
    input logic [6:0] drp_daddr,

    output logic xadc_eoc,
    output logic xadc_drdy,
    output logic [15:0] xadc_do,
    output logic xadc_primitive_busy
);

logic [15:0] vauxp_bus;
logic [15:0] vauxn_bus;
logic [7:0] alarm_unused;
logic [4:0] channel_unused;
logic eos_unused;
logic jtag_busy_unused;
logic jtag_locked_unused;
logic jtag_modified_unused;
logic [4:0] mux_address_unused;
logic over_temperature_unused;

assign vauxp_bus = {11'b0, vaux4_p, 4'b0};
assign vauxn_bus = {11'b0, vaux4_n, 4'b0};

XADC #(
    .INIT_40(16'h0014),
    .INIT_41(16'h3000),
    .INIT_42(16'h1000),
    .INIT_48(16'h0000),
    .INIT_49(16'h0000),
    .INIT_4A(16'h0000),
    .INIT_4B(16'h0000),
    .INIT_4C(16'h0000),
    .INIT_4D(16'h0000),
    .INIT_4E(16'h0000),
    .INIT_4F(16'h0000),
    .SIM_DEVICE("7SERIES")
) xadc_primitive_inst(
    .ALM(alarm_unused),
    .BUSY(xadc_primitive_busy),
    .CHANNEL(channel_unused),
    .DO(xadc_do),
    .DRDY(xadc_drdy),
    .EOC(xadc_eoc),
    .EOS(eos_unused),
    .JTAGBUSY(jtag_busy_unused),
    .JTAGLOCKED(jtag_locked_unused),
    .JTAGMODIFIED(jtag_modified_unused),
    .MUXADDR(mux_address_unused),
    .OT(over_temperature_unused),
    .CONVST(1'b0),
    .CONVSTCLK(1'b0),
    .DADDR(drp_daddr),
    .DCLK(clk),
    .DEN(drp_den),
    .DI(16'b0),
    .DWE(1'b0),
    .RESET(rst),
    .VAUXN(vauxn_bus),
    .VAUXP(vauxp_bus),
    .VN(1'b0),
    .VP(1'b0)
);

endmodule
