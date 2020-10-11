`define IDLE  4'b0000
`define RT    4'b0001
`define RWIH  4'b0011
`define RWHH  4'b0010
`define RBIH  4'b0110
`define RBHH  4'b0111
`define RXT   4'b0101
`define ADD   4'b0100
`define BUFF  4'b1100
`define END   4'b1101
// `define WHT   4'b1111

module RNN(clk,reset,busy,ready,i_en,idata,mdata_w,mce,mdata_r,maddr,msel);
input           clk, reset;
input           ready;
input    [31:0] idata;
input    [19:0] mdata_r;

output          busy;
output          i_en;
output          mce;
output   [16:0] maddr;
output   [19:0] mdata_w;
output    [2:0] msel;

// Please DO NOT modified the I/O signal
reg     [19:0] h [0:63];
reg     [19:0] h_next [0:63];
reg     [19:0] whh [0:4095];
reg     [19:0] wih [0:2047];
reg     [19:0] bih_bhh [0:63];
reg     [3:0]  state , state_next;
reg     [12:0] counter, counter_next;
reg     [19:0] WX_reg;
reg	[19:0] output_reg;
// reg     [19:0] bih_bhh_reg;
reg     [39:0] result_reg;
wire    [39:0] result_reg_next;
wire    [39:0] mul_out [0:63];
reg     [39:0] result_sub [0:63];
wire    [39:0] result [0:1];
wire    [19:0] wx_out [0:31];
reg     [19:0] WX_partial [0:31];
wire    [19:0] WX_partial_sum;
reg     [19:0] whh_source [0:63];
reg     [19:0] wih_source [0:31];
reg     [19:0] whh_source_reg [0:63];
reg     [19:0] wih_source_reg [0:31];
reg     [19:0] bih_bhh_source;
wire    [39:0] to_clip;
wire    [19:0] clipped;
wire    [19:0] row_sum_to_act, row_sum;
wire    complete;
wire    carry_bit;
reg     [10:0] t, t_next;
reg     [10:0] fetch, fetch_next;
wire    [5:0] counter_dec, counter_dec1;
integer i, j;
genvar  idx;

// generate
generate
    for (idx=0;idx<64;idx=idx+1) begin
        assign mul_out[idx] = $signed(whh_source_reg[idx]) * $signed(h[idx]);
    end
    for (idx=0;idx<32;idx=idx+1) begin
        assign wx_out[idx] = idata[idx] ? wih_source_reg[idx] : 20'd0;
    end
endgenerate

// assign WX_partial[0] = $signed(wx_out[0]) + $signed(wx_out[1]) + $signed(wx_out[2]) + $signed(wx_out[3]) + $signed(wx_out[4]) + $signed(wx_out[5]) + $signed(wx_out[6]) + $signed(wx_out[7]);
// assign WX_partial[1] = $signed(wx_out[8]) + $signed(wx_out[9]) + $signed(wx_out[10]) + $signed(wx_out[11]) + $signed(wx_out[12]) + $signed(wx_out[13]) + $signed(wx_out[14]) + $signed(wx_out[15]);
// assign WX_partial[2] = $signed(wx_out[16]) + $signed(wx_out[17]) + $signed(wx_out[18]) + $signed(wx_out[19]) + $signed(wx_out[20]) + $signed(wx_out[21]) + $signed(wx_out[22]) + $signed(wx_out[23]);
// assign WX_partial[3] = $signed(wx_out[24]) + $signed(wx_out[25]) + $signed(wx_out[26]) + $signed(wx_out[27]) + $signed(wx_out[28]) + $signed(wx_out[29]) + $signed(wx_out[30]) + $signed(wx_out[31]);
// assign WX_partial_sum = $signed(WX_partial[0]) + $signed(WX_partial[1]) + $signed(WX_partial[2]) + $signed(WX_partial[3]);

assign WX_partial_sum = $signed(WX_partial[0]) + $signed(WX_partial[1]) + $signed(WX_partial[2]) + $signed(WX_partial[3]) + $signed(WX_partial[4]) + $signed(WX_partial[5]) + $signed(WX_partial[6]) + $signed(WX_partial[7]) +
                        $signed(WX_partial[8]) + $signed(WX_partial[9]) + $signed(WX_partial[10]) + $signed(WX_partial[11]) + $signed(WX_partial[12]) + $signed(WX_partial[13]) + $signed(WX_partial[14]) + $signed(WX_partial[15]) +
                        $signed(WX_partial[16]) + $signed(WX_partial[17]) + $signed(WX_partial[18]) + $signed(WX_partial[19]) + $signed(WX_partial[20]) + $signed(WX_partial[21]) + $signed(WX_partial[22]) + $signed(WX_partial[23])+
                        $signed(WX_partial[24]) + $signed(WX_partial[25]) + $signed(WX_partial[26]) + $signed(WX_partial[27]) + $signed(WX_partial[28]) + $signed(WX_partial[29]) + $signed(WX_partial[30]) + $signed(WX_partial[31]);


// assign result_sub[0] =  $signed(mul_out[0]) + $signed(mul_out[1]) + $signed(mul_out[2]) + $signed(mul_out[3]) + $signed(mul_out[4]) + $signed(mul_out[5]) + $signed(mul_out[6]) + $signed(mul_out[7]);
// assign result_sub[1] =  $signed(mul_out[8]) + $signed(mul_out[9]) + $signed(mul_out[10]) + $signed(mul_out[11]) + $signed(mul_out[12]) + $signed(mul_out[13]) + $signed(mul_out[14]) + $signed(mul_out[15]);
// assign result_sub[2] =  $signed(mul_out[16]) + $signed(mul_out[17]) + $signed(mul_out[18]) + $signed(mul_out[19]) + $signed(mul_out[20]) + $signed(mul_out[21]) + $signed(mul_out[22]) + $signed(mul_out[23]);
// assign result_sub[3] =  $signed(mul_out[24]) + $signed(mul_out[25]) + $signed(mul_out[26]) + $signed(mul_out[27]) + $signed(mul_out[28]) + $signed(mul_out[29]) + $signed(mul_out[30]) + $signed(mul_out[31]);
// assign result[0] = $signed(result_sub[0]) + $signed(result_sub[1]) + $signed(result_sub[2]) + $signed(result_sub[3]);

assign result[0] =  $signed(result_sub[0]) + $signed(result_sub[1]) + $signed(result_sub[2]) + $signed(result_sub[3]) + $signed(result_sub[4]) + $signed(result_sub[5]) + $signed(result_sub[6]) + $signed(result_sub[7]) +
                    $signed(result_sub[8]) + $signed(result_sub[9]) + $signed(result_sub[10]) + $signed(result_sub[11]) + $signed(result_sub[12]) + $signed(result_sub[13]) + $signed(result_sub[14]) + $signed(result_sub[15]) +
                    $signed(result_sub[16]) + $signed(result_sub[17]) + $signed(result_sub[18]) + $signed(result_sub[19]) + $signed(result_sub[20]) + $signed(result_sub[21]) + $signed(result_sub[22]) + $signed(result_sub[23]) +
                    $signed(result_sub[24]) + $signed(result_sub[25]) + $signed(result_sub[26]) + $signed(result_sub[27]) + $signed(result_sub[28]) + $signed(result_sub[29]) + $signed(result_sub[30]) + $signed(result_sub[31]);

// assign result_sub[4] =  $signed(mul_out[32]) + $signed(mul_out[33]) + $signed(mul_out[34]) + $signed(mul_out[35]) + $signed(mul_out[36]) + $signed(mul_out[37]) + $signed(mul_out[38]) + $signed(mul_out[39]);
// assign result_sub[5] =  $signed(mul_out[40]) + $signed(mul_out[41]) + $signed(mul_out[42]) + $signed(mul_out[43]) + $signed(mul_out[44]) + $signed(mul_out[45]) + $signed(mul_out[46]) + $signed(mul_out[47]);
// assign result_sub[6] =  $signed(mul_out[48]) + $signed(mul_out[49]) + $signed(mul_out[50]) + $signed(mul_out[51]) + $signed(mul_out[52]) + $signed(mul_out[53]) + $signed(mul_out[54]) + $signed(mul_out[55]);
// assign result_sub[7] =  $signed(mul_out[56]) + $signed(mul_out[57]) + $signed(mul_out[58]) + $signed(mul_out[59]) + $signed(mul_out[60]) + $signed(mul_out[61]) + $signed(mul_out[62]) + $signed(mul_out[63]);
// assign result[1] = $signed(result_sub[4]) + $signed(result_sub[5]) + $signed(result_sub[6]) + $signed(result_sub[7]);

assign result[1] =  $signed(result_sub[32]) + $signed(result_sub[33]) + $signed(result_sub[34]) + $signed(result_sub[35]) + $signed(result_sub[36]) + $signed(result_sub[37]) + $signed(result_sub[38]) + $signed(result_sub[39]) +
                    $signed(result_sub[40]) + $signed(result_sub[41]) + $signed(result_sub[42]) + $signed(result_sub[43]) + $signed(result_sub[44]) + $signed(result_sub[45]) + $signed(result_sub[46]) + $signed(result_sub[47]) +
                    $signed(result_sub[48]) + $signed(result_sub[49]) + $signed(result_sub[50]) + $signed(result_sub[51]) + $signed(result_sub[52]) + $signed(result_sub[53]) + $signed(result_sub[54]) + $signed(result_sub[55]) +
                    $signed(result_sub[56]) + $signed(result_sub[57]) + $signed(result_sub[58]) + $signed(result_sub[59]) + $signed(result_sub[60]) + $signed(result_sub[61]) + $signed(result_sub[62]) + $signed(result_sub[63]);

assign result_reg_next = $signed(result[0]) + $signed(result[1]);
assign to_clip = result_reg;

assign row_sum_to_act = $signed(clipped) + $signed(WX_reg) + $signed(bih_bhh_source);

assign carry_bit = to_clip[39] ? (to_clip[15] & (|to_clip[14:0])) : to_clip[15];
assign clipped   = to_clip[35:16] + carry_bit;

assign complete = (state == `IDLE || state == `RT || state == `RXT) ? 1'b1:
                  (state == `RWHH) ? counter_next[12]:
                  (state == `RWIH) ? counter_next[11]:
                  (state == `BUFF) ? counter_next[0] & counter_next[1]:
                  counter_next[6];
assign counter_dec = counter[5:0] - 3;
assign counter_dec1 = counter[5:0] - 4;
always @(*) begin
    case(state)
    `IDLE: state_next = ready ? `RT : `IDLE;
    `RT  : state_next = (t_next == 0) ? `IDLE : `RWIH;
    `RWIH: state_next = complete ? `RWHH : `RWIH;
    `RWHH: state_next = complete ? `RBIH : `RWHH;
    `RBIH: state_next = complete ? `RBHH : `RBIH;
    `RBHH: state_next = complete ? `RXT : `RBHH;
    `RXT : state_next = `ADD;
    `ADD : state_next = complete ? `BUFF : `ADD;
    `BUFF: state_next = complete ? (fetch == t) ? `END : `ADD : `BUFF;
    `END : state_next = `IDLE;
    default: state_next = `IDLE;
    endcase
    counter_next = counter + 1;
end

always @(*) begin
    for (i=0;i<32;i=i+1) begin
        wih_source[i] = wih[i];
    end
    for (i=0;i<64;i=i+1) begin
        whh_source[i] = whh[i];
    end
    bih_bhh_source = bih_bhh[0];
    for (j=1;j<64;j=j+1) begin
        if (counter[5:0] == j) begin
            for (i=0;i<32;i=i+1) begin
                wih_source[i] = wih[j*32+i];
            end
            for (i=0;i<64;i=i+1) begin
                whh_source[i] = whh[j*64+i];
            end
        end  
    end
    for (j=1;j<64;j=j+1) begin
        if (counter_dec == j) begin
            bih_bhh_source = bih_bhh[j];
        end  
    end
    fetch_next = (state == `ADD && complete) ? fetch + 1 : fetch;
    t_next = (state == `RT) ? mdata_r[10:0] : t;
end

HTANH h1(
    .i(row_sum_to_act),
    .o(row_sum)
);

// output logic
assign busy = (state != `IDLE) ? 1 : 0;
assign i_en = (state == `RXT || (state == `BUFF && complete && fetch != t)) ? 1 : 0;
assign msel = (state == `BUFF || state == `ADD || state == `END) ? 3'b101 :
              (state == `RWHH) ? 3'b010 :
              (state == `RBIH) ? 3'b001 :
              (state == `RBHH) ? 3'b011 :
              (state == `RT) ? 3'b100 :
              3'b000;
assign mdata_w = output_reg; //((state == `ADD && counter[5:0] == 0) || state == `END) ? h_next[63] : h_next[counter_dec1];
assign mce = (state != `IDLE) ? 1 : 0;
assign maddr = (state == `ADD && counter[5:0] != 6'd0) ? {fetch, counter_dec1} :
               (state == `ADD || state == `END) ? {(fetch-1), 6'd63} :
               (state == `BUFF) ? {(fetch-1), counter_dec1} :
            //    (state == `RBIH || state == `RBHH) ? {11'd0, counter[5:0]}:
               {5'd0, counter[11:0]};

// sequential update
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= `IDLE;
        counter <= 0;
        t <= 0;
        fetch <= 0;
        WX_reg <= 0;
        result_reg <= 0;
        // bih_bhh_reg <= 0;
        for (i=0;i<64;i=i+1) begin
            h[i] <= 0;
        end
        for (i=0;i<64;i=i+1) begin
            whh_source_reg[i] <= 0;
            result_sub[i] <= 0;
        end
        for (i=0;i<32;i=i+1) begin
            wih_source_reg[i] <= 0;
            WX_partial[i] <= 0;
        end
        for (i=0;i<64;i=i+1) begin
            h_next[i] <= 0;
        end        
        for (i=0;i<4096;i=i+1) begin
            whh[i] <= 0;
        end
        for (i=0;i<2048;i=i+1) begin
            wih[i] <= 0;
        end
        for (i=0;i<64;i=i+1) begin
            bih_bhh[i] <= 0;
        end        
    end
    else begin
        state <= state_next;
        counter <= complete ? 0 : counter_next;
        t <= t_next;
        fetch <= fetch_next;
        // WX_reg <= 0;        
        // result_reg <= 0;
        // bih_bhh_reg <= 0;
        for (i=0;i<64;i=i+1) begin
            h[i] <= h[i];
            h_next[i] <= h_next[i];
        end
        for (i=0;i<64;i=i+1) begin
            whh_source_reg[i] <= whh_source[i];
            result_sub[i] <= mul_out[i];
        end
        for (i=0;i<32;i=i+1) begin
            wih_source_reg[i] <= wih_source[i];
            WX_partial[i] <= wx_out[i];
        end
        result_reg <= result_reg_next;
        WX_reg <= WX_partial_sum;   
        for (i=0;i<4096;i=i+1) begin
            whh[i] <= whh[i];
        end
        for (i=0;i<2048;i=i+1) begin
            wih[i] <= wih[i];
        end
        if(state == `BUFF) begin
            for (i=0;i<61;i=i+1) begin
                h[i] <= h_next[i];
            end
            h[61] <= (~counter[0] & ~counter[1]) ? row_sum : h[61];
            h[62] <= (counter[0] & ~counter[1]) ? row_sum : h[62];
            h[63] <= (~counter[0] & counter[1]) ? row_sum : h[63];
            h_next[61] <= (~counter[0] & ~counter[1]) ? row_sum : h_next[61];
            h_next[62] <= (counter[0] & ~counter[1]) ? row_sum : h_next[62];
            h_next[63] <= (~counter[0] & counter[1]) ? row_sum : h_next[63];
        end
        else if(state == `ADD) begin
            // bih_bhh_reg <= bih_bhh[counter[5:0]];
            h_next[counter_dec] <= row_sum;           
        end
        else if(state == `RWHH) begin
            whh[counter[11:0]] <= mdata_r;
        end
        else if(state == `RWIH) begin
            wih[counter[10:0]] <= mdata_r;
        end
        else if(state == `RBIH) begin
            bih_bhh[counter[5:0]] <= mdata_r;
        end
        else if(state == `RBHH) begin
            bih_bhh[counter[5:0]] <= mdata_r + bih_bhh[counter[5:0]];
        end
    end
end

always @(posedge clk or posedge reset) begin
	if(reset) begin
		output_reg <= 0;
	end
	else begin
		if (state == `ADD || state == `BUFF || state == `END) begin
			output_reg <= row_sum;
		end
		else begin
			output_reg <= 0;
		end
	end
end

endmodule

module HTANH(
    i,
    o
);

input signed        [19:0] i;
output reg signed   [19:0] o;

always @(*) begin
    if (!i[19] && (i[18:16] >= 3'd1)) begin
        o = 20'b0001_0000_0000_0000_0000;
    end
    else if (i[19] && (i[18:16] <= 3'b110)) begin
        o = 20'b1111_0000_0000_0000_0000;
    end
    else begin
        o = i;
    end
end

endmodule
