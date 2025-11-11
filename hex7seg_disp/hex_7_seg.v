module hex7seg(input wire [3:0] x, output reg [6:0] a);
   always @(*) begin
     case(x)
      0 : a <= 7'b0000001;
      1 : a <= 7'b1001111;
      2 : a <= 7'b0010010;
      3 : a <= 7'b0000110;
      4 : a <= 7'b1001100;
      5 : a <= 7'b0100100;
      6 : a <= 7'b0100000;
      7 : a <= 7'b0001111;
      8 : a <= 7'b0000000;
      9 : a <= 7'b0000100;
      4'hA : a <= 7'b0001000;
      4'hB : a <= 7'b1100000;
      4'hC : a <= 7'b0110001;
      4'hD : a <= 7'b1000010;
      4'hE : a <= 7'b0110000;
      4'hF : a <= 7'b0111000;
      default : a <= 7'b0000001;
      endcase 
   end
endmodule

///////////////////////////////////////////////////////////////////////////////////////////// constrints file ///////////////////////////////////////////////////////////////////////////////////////////////

# XDC Constraints File for bcd_to_7seg project

# 4 Switches for BCD input
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports x[0]]; # Sch=sw[0]
set_property -dict { PACKAGE_PIN L16   IOSTANDARD LVCMOS33 } [get_ports x[1]]; # Sch=sw[1]
set_property -dict { PACKAGE_PIN M13   IOSTANDARD LVCMOS33 } [get_ports x[2]]; # Sch=sw[2]
set_property -dict { PACKAGE_PIN R15   IOSTANDARD LVCMOS33 } [get_ports x[3]]; # Sch=sw[3]

# 7-Segment Display Segments
# Note: The schematic names ca, cb, etc., typically map to segments a, b, etc.
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports a[0]]; # Sch=ca (Segment A)
set_property -dict { PACKAGE_PIN R10   IOSTANDARD LVCMOS33 } [get_ports a[1]]; # Sch=cb (Segment B)
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports a[2]]; # Sch=cc (Segment C)
set_property -dict { PACKAGE_PIN K13   IOSTANDARD LVCMOS33 } [get_ports a[3]]; # Sch=cd (Segment D)
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports a[4]]; # Sch=ce (Segment E)
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports a[5]]; # Sch=cf (Segment F)
set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports a[6]]; # Sch=cg (Segment G)

# You will also need to connect the anode enable pins for the display to work.
# For example, on a Nexys A7, you would add constraints for the AN[7:0] ports
# and drive one of them low in your Verilog to enable a digit.
