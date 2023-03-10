`timescale 1ns/1ns

module tb_Uart_transmitter();
  reg clk, rst_n, pwr, pen, rxd;
  reg [1:0] psel;
  reg [31:0] pwData, pAdd;
  wire prdata, txd, pready;

//Test transmitter
Uart uart(.clk(clk), .pwData(pwData), .pAdd(pAdd), .rst_n(rst_n), .pwr(pwr), .psel(psel), .pen(pen),
          .prdata(prdata), .pready(pready), .rxd(rxd), .txd(txd));

always #1 clk = ~clk;

initial begin
  clk <= 0;rst_n <= 0; pwData <= 0; pAdd <= 0; pwr <= 0; psel <= 2'b00; pen <= 0; 
  #3 rst_n <= 1; pAdd <= 32'd15; pwr <= 1; psel <= 2'b10;pwData<= "ABCD";
  #2 pen = 1;
end
  
  
endmodule

module tb_Uart_reciever();

reg clk, rst_n, pwr, pen, rxd;
reg [1:0] psel;
reg [31:0] pwData, pAdd;
wire prdata, txd, pready;

//Test transmitter
Uart uart(.clk(clk), .pwData(pwData), .pAdd(pAdd), .rst_n(rst_n), .pwr(pwr), .psel(psel), .pen(pen),
          .prdata(prdata), .pready(pready), .rxd(rxd), .txd(txd));

always #1 clk = ~clk;

initial begin
  clk <= 0; pwData <= 0; pAdd <= 0; rst_n <= 0; pwr <= 0; psel <= 2'b00; pen <= 0; 
  #3 rst_n <= 1; pAdd <= 32'd15; pwr <= 0; psel <= 2'b10; 
  #2 pen = 1;
  #37 rxd <= 0;   //Start bit
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;    //Parity bit (no error)
  #32 rxd = 1;    //Stop bit (no error)
  /*------------------------------------------------*/
  #32 rxd = 0;   //Start bit
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;    //Parity bit (no error)
  #32 rxd = 1;    //Stop bit (no error)
/*------------------------------------------------*/
  #32 rxd = 0;   //Start bit
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;    //Parity bit (no error)
  #32 rxd = 1;    //Stop bit (no error)
/*------------------------------------------------*/
  #32 rxd = 0;   //Start bit
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;   
  #32 rxd = 1;
  #32 rxd = 0;    //Parity bit (no error)
  #32 rxd = 1;    //Stop bit (no error)
end
endmodule