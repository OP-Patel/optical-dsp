package fir_coefficients_pkg;

localparam logic [1:0] FIR_BANK_IDENTITY = 2'b00;
localparam logic [1:0] FIR_BANK_AVERAGE_4 = 2'b01;
localparam logic [1:0] FIR_BANK_AVERAGE_FULL = 2'b10;
localparam logic [1:0] FIR_BANK_SATURATION_TEST = 2'b11;

function automatic logic signed [15:0] fir_coefficient(
    input logic [1:0] bank,
    input int unsigned tap,
    input int unsigned taps
);
begin
    fir_coefficient = 16'sd0;

    case (bank)
        FIR_BANK_IDENTITY: begin
            if (tap == 0)
                fir_coefficient = 16'sd16384;
        end
        FIR_BANK_AVERAGE_4: begin
            if (tap < 4)
                fir_coefficient = 16'sd4096;
        end
        FIR_BANK_AVERAGE_FULL: begin
            if (tap < taps)
                fir_coefficient = 16'sd16384 / taps;
        end
        FIR_BANK_SATURATION_TEST: begin
            fir_coefficient = 16'sd32767;
        end
        default: fir_coefficient = 16'sd0;
    endcase
end
endfunction

endpackage
