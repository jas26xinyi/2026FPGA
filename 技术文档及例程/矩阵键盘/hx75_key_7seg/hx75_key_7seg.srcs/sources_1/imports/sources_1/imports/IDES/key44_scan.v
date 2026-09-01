module key44(
	input clk,  //50MHZ
	input reset, //复位高电平有效
	input [3:0] row,  //行
	output reg [3:0] col,   //列
	output key_valid,
	output reg [3:0] key_value  //键值
	);

	reg [5:0] count;//delay_20ms
	reg [2:0] state;  //状态标志
	reg key_flag;   //按键标志位
	reg clk_500khz;  //500KHZ时钟信号
	reg [3:0] col_reg;  //寄存扫描列值
	reg [3:0] row_reg;  //寄存扫描行值
	
	assign key_valid = key_flag;
	
	always @(posedge clk or posedge reset)
		if(reset) begin clk_500khz<=0; count<=0; end
		else
		begin
			if(count>=50) begin clk_500khz<=~clk_500khz;count<=0;end
			else count<=count+1;
		end
		
	always @(posedge clk_500khz or posedge reset)
		if(reset) begin col<=4'b0000;state<=0; end
        else   begin 
          case (state)
			0: begin
				col[3:0]<=4'b0000;
				key_flag<=1'b0;
				if(row[3:0]!=4'b1111) begin state<=1;col[3:0]<=4'b1110;end //有键按下，扫描第一行
                else state<=0;
			end 
			1: begin
				if(row[3:0]!=4'b1111) begin state<=5;end   //判断是否是第一行
				else  begin state<=2;col[3:0]<=4'b1101;end  //扫描第二行
			end 

			2:	begin    
			  if(row[3:0]!=4'b1111) begin state<=5;end    //判断是否是第二行
			  else  begin state<=3;col[3:0]<=4'b1011;end  //扫描第三行
           end

			3:   begin    
				if(row[3:0]!=4'b1111) begin state<=5;end   //判断是否是第三一行
				else  begin state<=4;col[3:0]<=4'b0111;end  //扫描第四行
			end
			
			4:  begin    
				if(row[3:0]!=4'b1111) begin state<=5;end  //判断是否是第一行
				else  state<=0;
			end

			5:  begin  
				if(row[3:0]!=4'b1111) 
					begin
						col_reg<=col;  //保存扫描列值
						row_reg<=row;  //保存扫描行值
						state<=5;
						key_flag<=1'b1;  //有键按下
					end             
				else
					begin state<=0;end
			end    
		endcase 
    end           

	always @(clk_500khz or col_reg or row_reg)
    begin
      if(key_flag==1'b1) 
        begin
            case ({row_reg,col_reg})
                 8'b1110_1110:key_value<=4'H0;
                 8'b1110_1101:key_value<=4'H1;
                 8'b1110_1011:key_value<=4'H2;
                 8'b1110_0111:key_value<=4'H3;
                 8'b1101_1110:key_value<=4'H4;
                 8'b1101_1101:key_value<=4'H5;
                 8'b1101_1011:key_value<=4'H6;
                 8'b1101_0111:key_value<=4'H7;
                 8'b1011_1110:key_value<=4'H8;
                 8'b1011_1101:key_value<=4'H9;
                 8'b1011_1011:key_value<=4'Ha;
                 8'b1011_0111:key_value<=4'Hb;
                 8'b0111_1110:key_value<=4'Hc;
                 8'b0111_1101:key_value<=4'Hd;
                 8'b0111_1011:key_value<=4'He;
                 8'b0111_0111:key_value<=4'Hf;     
            endcase 
        end   
   end   
   
 endmodule