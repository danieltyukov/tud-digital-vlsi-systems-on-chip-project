// Behavioral simulation stub for the standard-cell clock-gating latch.
// This is only used to let RTL simulation elaborate without the foundry model.
module TLATNCAX2 (
    input  wire CK,
    input  wire E,
    output wire ECK
);
    assign ECK = CK & E;
endmodule
