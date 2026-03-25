
library ieee;
  use ieee.std_logic_1164.all;

entity vector_to_axis is
  generic (
    vector_width    : integer := 32;
    axis_data_width : integer := 32
  );
  port (
    aclk          : in    std_logic;
    aresetn       : in    std_logic;
    vector_in     : in    std_logic_vector(vector_width - 1 downto 0);
      valid_in     : in    std_logic;
  -- AXI4 Stream output
    m_axis_tdata  : out   std_logic_vector(axis_data_width - 1 downto 0);
    m_axis_tkeep  : out   std_logic_vector((axis_data_width / 8) - 1 downto 0);
    m_axis_tvalid : out   std_logic;
    m_axis_tready : in    std_logic;
    m_axis_tlast  : out   std_logic
  );
end entity vector_to_axis;

architecture rtl of vector_to_axis is

    function calculate_index_end return integer is
    begin
        if (vector_width / axis_data_width) > 1 then
            return (vector_width / axis_data_width) - 1;
        else
            return 0;
        end if;
    end function;

    type state_type is (IDLE, SEND);
  signal state : state_type := IDLE;
  signal index : integer range 0 to calculate_index_end := 0;

begin

    m_axis_tdata <= vector_in((index + 1) * axis_data_width - 1 downto index * axis_data_width);

    main : process(aclk, aresetn)
    begin
        if (aresetn = '0') then
            state <= IDLE;
            index <= 0;
            m_axis_tdata <= (others => '0');
            m_axis_tkeep <= (others => '1'); -- Assuming all bytes are valid
            m_axis_tvalid <= '0';
            m_axis_tlast <= '0';
        elsif rising_edge(aclk) then
            case state is
                when IDLE =>
                    if valid_in = '1' then
                        m_axis_tvalid <= '1';
                        state <= SEND;
                        index <= 0;
                    else
                        state <= IDLE;
                    end if;
                when SEND =>
                    if m_axis_tready = '1' then
                        m_axis_tvalid <= '1';
                        if index = calculate_index_end then
                            m_axis_tlast <= '1';
                            state <= IDLE;
                        else
                            index <= index + 1;
                            state <= SEND;
                        end if;
                    else
                        state <= SEND; -- Wait until ready
                    end if;
                when others =>
                    state <= IDLE;
            end case;
            end if;
    end process;

end architecture rtl;

