library ieee;
  use ieee.std_logic_1164.all;

entity ethernet_framer is
  generic (
    data_width : integer := 32
  );
  port (
    clk      : in    std_logic;
    rst_n    : in    std_logic;
    -- AXI4 Stream Slave input
    s_axis_tdata  : in    std_logic_vector(data_width - 1 downto 0);
    s_axis_tkeep  : in    std_logic_vector((data_width / 8);
    s_axis_tvalid : in    std_logic;
    s_axis_tlast  : in    std_logic;
    s_axis_tready : out   std_logic;
    
    -- AXI4 Stream Master output
    m_axis_tdata  : out   std_logic_vector(data_width - 1 downto 0);
    m_axis_tkeep  : out   std_logic_vector((data_width / 8)
    m_axis_tvalid : out   std_logic;
    m_axis_tlast  : out   std_logic;
    m_axis_tready : in    std_logic

  );
end entity ethernet_framer;

architecture rtl of ethernet_framer is

  type state_type is (idle, header, framing);
  signal state : state_type;
begin

end architecture rtl;
