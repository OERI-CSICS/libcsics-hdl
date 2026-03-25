
library ieee;
  use ieee.std_logic_1164.all;

entity vector_to_axis is
  generic (
    vector_width    : integer := 32;
    axis_data_width : integer := 32
  );
  port (
    aclk      : in    std_logic;
    aresetn   : in    std_logic;
    vector_in : in    std_logic_vector(vector_width - 1 downto 0);
    valid_in  : in    std_logic;
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

    if ((vector_width / axis_data_width) > 1) then
      return (vector_width / axis_data_width) - 1;
    else
      return 0;
    end if;

  end function calculate_index_end;

  function calculate_tkeep_end return std_logic_vector is
      variable result : std_logic_vector((axis_data_width / 8) - 1 downto 0);
      constant valid_bytes : integer := (vector_width / 8) mod (axis_data_width / 8);
  begin

      if (valid_bytes = 0) then
          result := (others => '1');
          return result;
      end if;

      result := (others => '0');
      for i in 0 to valid_bytes - 1 loop
          result(i) := '1';
      end loop;

      return result;
  end function calculate_tkeep_end;

  type state_type is (idle, send);

  constant tkeep_end : std_logic_vector(axis_data_width / 8 - 1 downto 0) := calculate_tkeep_end;
  constant index_end : integer := calculate_index_end;
  signal   state     : state_type;
  signal   index     : integer range 0 to index_end;
  signal vector_reg : std_logic_vector(vector_width - 1 downto 0);

begin

  m_axis_tdata  <= vector_reg((index + 1) * axis_data_width - 1 downto index * axis_data_width);
  m_axis_tvalid <= '1' when state = send else
                   '0';
  m_axis_tlast  <= '1' when (state = send and index = index_end) else
                   '0';
  m_axis_tkeep  <= tkeep_end when state = send and index = index_end else
                   (others => '1');

  main : process (aclk, aresetn) is
  begin

    if (aresetn = '0') then
      state <= idle;
      index <= 0;
    elsif rising_edge(aclk) then

      case state is

        when idle =>

          if (valid_in = '1') then
            state <= send;
            index <= 0;
            vector_reg <= vector_in;
          else
            state <= idle;
          end if;

        when send =>

          if (m_axis_tready = '1') then
            if (index = index_end) then
              state <= idle;
            else
              index <= index + 1;
              state <= send;
            end if;
          else
            state <= send;
          end if;

        when others =>

          state <= idle;

      end case;

    end if;

  end process main;

end architecture rtl;

