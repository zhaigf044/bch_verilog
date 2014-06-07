`timescale 1ns / 1ps

module bch_decode #(
	parameter N = 15,
	parameter K = 5,
	parameter T = 3,	/* Correctable errors */
	parameter OPTION = "SERIAL"
) (
	input clk,
	input start,
	input data_in,
	output reg ready = 1,
	output reg output_valid = 0,
	output reg data_out = 0
);

`include "bch.vh"

localparam TCQ = 1;
localparam M = n2m(N);
localparam BUF_SIZE = T < 3 ? (N + 2) : (OPTION == "SERIAL" ? (N + T * (M + 2) + 0) : (N + T*2 + 1));

if (BUF_SIZE > 2 * N) begin
	wire [log2(BUF_SIZE - N + 3)-1:0] wait_count;
	counter #(BUF_SIZE - N + 2) u_wait(
		.clk(clk),
		.reset(start),
		.ce(!ready),
		.count(wait_count)
	);
	always @(posedge clk) begin
		if (start)
			ready <= #TCQ 0;
		else if (wait_count == BUF_SIZE - N + 2)
			ready <= #TCQ 1;
	end
end

reg [BUF_SIZE-1:0] buf_ = 0;

/* Process syndromes */
wire [2*T*M-1:M] syndromes;
wire syn_done;
wire err_start;
wire err_valid;
wire err;

bch_syndrome #(M, T) u_bch_syndrome(
	.clk(clk),
	.start(start),
	.done(syn_done),
	.data_in(data_in),
	.out(syndromes)
);

if (T < 3) begin
	dec_decode #(N, K, T) u_decode(
		.clk(clk),
		.start(syn_done),
		.syndromes(syndromes),
		.err_start(err_start),
		.err_valid(err_valid),
		.err(err)
	);
end else begin
	tmec_decode #(N, K, T, OPTION) u_decode(
		.clk(clk),
		.start(syn_done),
		.syndromes(syndromes),
		.err_start(err_start),
		.err_valid(err_valid),
		.err(err)
	);
end

always @(posedge clk) begin
	buf_ <= #TCQ {buf_[BUF_SIZE-2:0], data_in};
	data_out <= #TCQ (buf_[BUF_SIZE-1] ^ err) && err_valid;
	output_valid <= #TCQ err_valid;
end


endmodule
