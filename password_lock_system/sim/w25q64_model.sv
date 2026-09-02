`timescale 1ns/1ps
module w25q64_model(
 input wire cs_n,input wire sclk,input wire mosi,output reg miso
);
 reg [7:0] mem[0:8191];
 reg [7:0] in_shift,out_shift,command;
 integer bit_count,byte_count,i;
 integer address;
 reg write_enable;
 reg [1:0] id_index;
 initial begin for(i=0;i<8192;i=i+1)mem[i]=8'hFF; miso=1;write_enable=0;end
 always @(negedge cs_n) begin
   bit_count=0;byte_count=0;in_shift=0;out_shift=8'hFF;command=0;address=0;id_index=0;miso=1;
 end
 always @(posedge cs_n) begin
   if(command==8'h02)write_enable=0;
 end
 always @(negedge sclk) if(!cs_n) begin
   miso=out_shift[7];out_shift={out_shift[6:0],1'b1};
 end
 always @(posedge sclk) if(!cs_n) begin : sample
   reg [7:0] received;
   in_shift={in_shift[6:0],mosi};
   if(bit_count==7) begin
     received=in_shift;bit_count=0;
     if(byte_count==0) begin
       command=received;
       case(received)
         8'h9F: begin out_shift=8'hEF;id_index=0;end
         8'h05: out_shift=8'h00;
         8'h06: write_enable=1;
       endcase
     end else case(command)
       8'h9F: begin
         id_index=id_index+1;
         case(id_index)1:out_shift=8'h40;2:out_shift=8'h17;default:out_shift=8'hFF;endcase
       end
       8'h05: out_shift=8'h00;
       8'h03: begin
         if(byte_count<=3) begin
           address=(address<<8)|received;
           if(byte_count==3)out_shift=mem[address&8191];
         end else begin address=(address+1)&8191;out_shift=mem[address];end
       end
       8'h20: begin
         if(byte_count<=3)address=(address<<8)|received;
         if(byte_count==3 && write_enable) begin
           address=address&13'h1000;
           for(i=0;i<4096;i=i+1)mem[address+i]=8'hFF;
           write_enable=0;
         end
       end
       8'h02: begin
         if(byte_count<=3)address=(address<<8)|received;
         else if(write_enable) begin mem[address&8191]=mem[address&8191]&received;address=address+1;end
       end
     endcase
     byte_count=byte_count+1;
   end else bit_count=bit_count+1;
 end
endmodule
