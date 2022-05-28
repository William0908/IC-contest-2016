//===================================================
// Project: IC Contest_2016
// Designer: William
// Date:2022/03/14
// Version: 1.0
//===================================================

`timescale 1ns/10ps
module LBP( 
	clk, 
	reset, 
	gray_addr, 
	gray_req, 
	gray_ready, 
	gray_data, 
	lbp_addr, 
	lbp_valid, 
	lbp_data, 
	finish
);

input clk;
input reset;
input gray_ready;
input [7:0] gray_data;
output reg [13:0] gray_addr;
output reg gray_req;
output reg [13:0] lbp_addr;
output reg lbp_valid;
output reg [7:0] lbp_data;
output reg finish;
// 
reg [2:0] state;
reg [2:0] n_state;
// STATE 
parameter IDLE   = 3'b000;
parameter MASK   = 3'b001;
parameter INPUT  = 3'b010; // get 8 pixels per round
parameter LBP    = 3'b011;
parameter OUTPUT = 3'b100;
parameter FINISH = 3'b101;
// Conrol signal
wire in_ready;
reg valid_flag;
reg [3:0] in_cnt;
//reg [3:0] lbp_cnt;
//
reg [13:0] axis;
reg [13:0] axis_X, axis_Y;
reg [13:0] c [0:8]; // c[4] is central position 
reg [7:0] in_data [0:8];
reg [7:0] T0, T1, T2, T3, T5, T6, T7, T8;
reg [7:0] M0, M1, M2, M3, M5, M6, M7, M8;

integer i;

//====================================================================
// FSM current state
always @(posedge clk or posedge reset) begin
	if (reset) begin
		state <= 0;		
	end
	else begin
		state <= n_state;
	end
end

// FSM next state
always @(*) begin
	case(state)
         IDLE: begin
            if (gray_ready) n_state = MASK;
            else n_state = state;
         end
         MASK: begin
         	n_state = INPUT;
         end
         INPUT: begin
         	if (in_ready) n_state = LBP;
         	else n_state = state;
         end
         LBP: begin
         	if (valid_flag) n_state = OUTPUT;
         	else n_state = state;
         end
         OUTPUT: begin
         	if (finish) n_state = FINISH;
         	else if (!lbp_valid) n_state = MASK;
         	else n_state = state;
         end
         FINISH: begin
         	n_state = FINISH;
         end
         default: begin
         	n_state = state;
         end
    endcase
end

//
always @(posedge clk or posedge reset) begin
	if (reset) begin
		gray_req <= 0;
	end
	else if (n_state == INPUT) begin
		gray_req <= 1;
	end
	else begin
		gray_req <= 0;
	end
end

// Input counter
always @(posedge clk or posedge reset) begin
	if (reset) begin
		in_cnt <= 0;
	end
	else begin
		case(state)
		     INPUT: begin
		     	if (in_cnt < 10) in_cnt <= in_cnt + 1;
 		        else in_cnt <= in_cnt;;
		     end
		     OUTPUT: begin
		     	in_cnt <= 0;
		     end
		     default: begin
		     	in_cnt <= in_cnt;
		     end
		endcase
	end
end

assign in_ready = (in_cnt == 9) ? 1 : 0;

// 3*3 mask
always @(posedge clk or posedge reset) begin
	if (reset) begin
		axis_X <= 1;
		axis_Y <= 0;
	end 
	else begin
        case(state) 
             MASK: begin
             	if (axis_Y == 126) begin
             		axis_Y <= 1;
             		if (axis_X == 126) begin
             			axis_X <= 1;
             		end
             		else begin
             			axis_X <= axis_X + 1;
             		end
             	end
             	else begin
             	    axis_X <= axis_X;
             		axis_Y <= axis_Y + 1;
             	end
             end
             default: begin
             	    axis_X <= axis_X;
             	    axis_Y <= axis_Y;
             end
        endcase
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		axis <= 0;	
	end
	else begin
		axis <= axis_Y + axis_X * 128;
	end
end

// Get coordinate of the pixels
always @(*) begin
	// Central position
	c[4] = axis_Y + axis_X * 128;
	c[0] = c[4] - 129;
	c[1] = c[4] - 128;
	c[2] = c[4] - 127;
	c[3] = c[4] - 1;
	c[5] = c[4] + 1;
	c[6] = c[4] + 127;
	c[7] = c[4] + 128;
	c[8] = c[4] + 129;
end

// Get the address of 8 pixels
always @(posedge clk or posedge reset) begin
 	if (reset) begin
 		gray_addr <= 14'd0;
 	end
 	else begin
 		case(state)
             INPUT: begin
             	gray_addr <= c[in_cnt];
             end
             default: begin
             	gray_addr <= gray_addr;
             end
 		endcase
 	end
 end

// LBP counter
// always @(posedge clk or posedge reset) begin
// 	if (reset) begin
// 		lbp_cnt <= 0;
// 	end
// 	else begin
// 		case(state)
// 		     LBP: begin
// 		       if (lbp_cnt < 8) lbp_cnt <= lbp_cnt + 1;
// 		       else lbp_cnt <= lbp_cnt;
// 		     end
// 		     OUTPUT: begin
// 		     	lbp_cnt <= 0;
// 		     end
// 		     default: begin
// 		     	lbp_cnt <= lbp_cnt;
// 		     end
// 		endcase
// 	end
// end
 
// Get gray-level value
always @(posedge clk or posedge reset) begin
  	if (reset) begin
  		for(i = 0; i < 9; i = i + 1) begin
  			in_data[i] <= 8'd0;
  		end
  	end
  	else begin
  		in_data[in_cnt - 1] <= gray_data;  
  	end
end 

// Threshold
always @(*) begin
	T0 = (in_data[0] >= in_data[4]) ? 1 : 0;
	T1 = (in_data[1] >= in_data[4]) ? 1 : 0;
	T2 = (in_data[2] >= in_data[4]) ? 1 : 0;
	T3 = (in_data[3] >= in_data[4]) ? 1 : 0;
	T5 = (in_data[5] >= in_data[4]) ? 1 : 0;
	T6 = (in_data[6] >= in_data[4]) ? 1 : 0;
	T7 = (in_data[7] >= in_data[4]) ? 1 : 0;
	T8 = (in_data[8] >= in_data[4]) ? 1 : 0;
end

// Multiply
always @(*) begin
	M0 = T0;
	M1 = T1 << 1;
	M2 = T2 << 2;
	M3 = T3 << 3;
	M5 = T5 << 4;
	M6 = T6 << 5;
	M7 = T7 << 6;
	M8 = T8 << 7;
end

// LBP
always @(posedge clk or posedge reset) begin
	if (reset) begin
		lbp_data <= 8'd0;	
	end
	else begin
		case(state)
             LBP: begin
             	lbp_data <= M0 + M1 + M2 + M3 + M5 + M6 + M7 + M8;
             end
             default: begin
             	lbp_data <= lbp_data;
             end
		endcase
	end
end

// LBP address
always @(posedge clk or posedge reset) begin
 	if (reset) begin
 		lbp_addr <= 14'd0;
 	end
 	else begin
 		case(state)
             INPUT: begin
             	lbp_addr <= axis;
             end
             default: begin
             	lbp_addr <= lbp_addr;
             end
 		endcase
 	end
 end

// Valid flag
always @(posedge clk or posedge reset) begin
	if (reset) begin
		valid_flag <= 0;
	end
	else begin
		case(state)
             LBP: begin
             	valid_flag <= ~ valid_flag; 
             end
             default: begin
             	valid_flag <= valid_flag;
             end
		endcase
	end
end


// Output logic
always @(posedge clk or posedge reset) begin
 	if (reset) begin
 		lbp_valid <= 0;
 	end
 	else if (state == LBP && valid_flag) begin
 		lbp_valid <= 1;
 	end
 	else begin
 		lbp_valid <= 0;
 	end
end

// Finish
always @(posedge clk or posedge reset) begin
	if (reset) begin
		finish <= 0; 
	end
	else if (axis == 16254 && in_cnt == 10) begin
		finish <= 1;
	end
	else begin
		finish <= finish;
	end
end

//====================================================================
endmodule



