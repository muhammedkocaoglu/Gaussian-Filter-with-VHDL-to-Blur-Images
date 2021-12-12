----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Muhammed KOCAOGLU
-- 
-- Create Date: 12/10/2021 10:47:09 PM
-- Design Name: 
-- Module Name: top - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

PACKAGE my_data_types IS
    TYPE MemType2D IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
    TYPE MemType3D IS ARRAY (INTEGER RANGE <>) OF MemType2D(0 to 4);
END my_data_types;
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.my_data_types.ALL; -- user-defined package

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY top IS
    PORT (
        CLK           : IN STD_LOGIC;
        filter_valid  : IN STD_LOGIC;
        filter_data_i : IN MemType2D(0 to 4);
        filter_data_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        filter_ready  : OUT STD_LOGIC;
        filteredPixelReady : out std_logic
    );
END top;

ARCHITECTURE Behavioral OF top IS
    COMPONENT fpu IS
        PORT (
            clk_i : IN STD_LOGIC;
            opa_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Default: FP_WIDTH=32 
            opb_i       : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            fpu_op_i    : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
            rmode_i     : IN STD_LOGIC_VECTOR(1 DOWNTO 0); -- 00 = round to nearest even(default), 
            output_o    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            start_i     : IN STD_LOGIC; -- is also restart signal
            ready_o     : OUT STD_LOGIC;
            -- Exceptions
            ine_o       : OUT STD_LOGIC; -- inexact
            overflow_o  : OUT STD_LOGIC; -- overflow
            underflow_o : OUT STD_LOGIC; -- underflow
            div_zero_o  : OUT STD_LOGIC; -- divide by zero
            inf_o       : OUT STD_LOGIC; -- infinity
            zero_o      : OUT STD_LOGIC; -- zero
            qnan_o      : OUT STD_LOGIC; -- queit Not-a-Number
            snan_o      : OUT STD_LOGIC  -- signaling Not-a-Number
        );
    END COMPONENT;

    SIGNAL opa_i_array      : MemType2D(0 to 4);
    SIGNAL opb_i_array      : MemType2D(0 to 4);
    SIGNAL output_o_array   : MemType2D(0 to 5) := (others => (others => '0'));
    SIGNAL opa_i_add_array  : MemType2D(0 to 2);
    SIGNAL opb_i_add_array  : MemType2D(0 to 2);
    SIGNAL output_o_add_array   : MemType2D(0 to 2);
    CONSTANT gaussian_coeff : MemType3D(0 to 4) := (

        (x"3d171319", x"3d206aa1", x"3d23a83b", x"3d206aa1", x"3d171319"),
        (x"3d206aa1", x"3d2a560d", x"3d2dc6f3", x"3d2a560d", x"3d206aa1"),
        (x"3d23a83b", x"3d2dc6f3", x"3d3149a5", x"3d2dc6f3", x"3d23a83b"),
        (x"3d206aa1", x"3d2a560d", x"3d2dc6f3", x"3d2a560d", x"3d206aa1"),
        (x"3d171319", x"3d206aa1", x"3d23a83b", x"3d206aa1", x"3d171319"));

    SIGNAL start_i : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0'); -- is also restart signal
    SIGNAL ready_o : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL start_add_i : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0'); -- is also restart signal
    SIGNAL ready_add_o : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');

    TYPE states IS (
        S_IDLE,
        S_MUL,
        S_ADD_STAGE_1,
        S_ADD_STAGE_2,
        S_ADD_STAGE_3
    );
    SIGNAL state : states := S_IDLE;

    SIGNAL cntr           : INTEGER   := 0;
    SIGNAL start_i_enable : STD_LOGIC := '0';

BEGIN

    P_MAIN : PROCESS (CLK)
    BEGIN
        IF rising_edge(CLK) THEN
            start_i <= (OTHERS => '0');
            start_add_i <= (OTHERS => '0');
            filter_ready    <= '0';
            filteredPixelReady  <= '0';
            CASE state IS
                WHEN S_IDLE =>
                    IF filter_valid = '1' THEN
                        state          <= S_MUL;
                        start_i_enable <= '1';
                    END IF;
                    if cntr = 5 then
                        cntr    <= 0;
                        filteredPixelReady  <= '1';
                        output_o_array(5)  <= (others => '0');
                        filter_data_o <= output_o_add_array(0);
                    end if;
                    
                WHEN S_MUL =>
                    FOR i IN 0 TO 4 LOOP
                        IF start_i_enable = '1' THEN
                            opa_i_array(i) <= filter_data_i(i);
                            opb_i_array(i) <= gaussian_coeff(i)(cntr);
                            start_i        <= (OTHERS => '1');
                            start_i_enable <= '0';
                        END IF;

                        IF ready_o(0) = '1' THEN
                            state         <= S_ADD_STAGE_1;
                            start_i_enable  <= '1';
                        END IF;
                    END LOOP;

                WHEN S_ADD_STAGE_1 =>
                    FOR i in 0 to 2 loop 
                        IF start_i_enable = '1' THEN
                            opa_i_add_array(i)  <=  output_o_array(i);
                            opb_i_add_array(i)  <= output_o_array(5-i);
                            start_add_i <= (OTHERS => '1');
                            start_i_enable <= '0';
                        end if;
                        IF ready_add_o(0) = '1' THEN
                            state         <= S_ADD_STAGE_2;
                            start_i_enable  <= '1';
                        END IF;
                    end loop;

                when S_ADD_STAGE_2 =>
                    FOR i in 0 to 1 loop 
                        IF start_i_enable = '1' THEN
                            if i = 0 then
                                opa_i_add_array(i)  <=  output_o_add_array(i);
                                opb_i_add_array(i)  <= output_o_add_array(2-i);
                                start_add_i <= (OTHERS => '1');
                                start_i_enable <= '0';
                            elsif i = 1 then
                                opa_i_add_array(i)  <=  output_o_add_array(i);
                                opb_i_add_array(i)  <= (others => '0');
                                start_add_i <= (OTHERS => '1');
                                start_i_enable <= '0';
                            end if;
                        end if;
                        IF ready_add_o(0) = '1' THEN
                            state         <= S_ADD_STAGE_3;
                            start_i_enable  <= '1';
                        END IF;
                    end loop;

                when S_ADD_STAGE_3 =>
                    IF start_i_enable = '1' THEN
                        opa_i_add_array(0)  <= output_o_add_array(0);
                        opb_i_add_array(0)  <= output_o_add_array(1);
                        start_add_i <= (OTHERS => '1');
                        start_i_enable <= '0';
                    end if;
                    IF ready_add_o(0) = '1' THEN
                        output_o_array(5)   <= output_o_add_array(0);
                        filter_ready    <= '1';
                        cntr            <= cntr + 1;
                        state           <= S_IDLE;
                    END IF;
            END CASE;
        END IF;
    END PROCESS;

    GEN_MULTIPLY : FOR i IN 0 TO 4 GENERATE
        fpu_Inst : fpu
        PORT MAP(
            clk_i    => CLK,
            opa_i    => opa_i_array(i),
            opb_i    => opb_i_array(i),
            fpu_op_i => "010", -- multiply
            rmode_i  => "00",  -- 00 = round to nearest even(default), 
            output_o => output_o_array(i),
            start_i => start_i(i), -- is also restart signal
            ready_o => ready_o(i),
            ine_o       => OPEN, -- inexact
            overflow_o  => OPEN, -- overflow
            underflow_o => OPEN, -- underflow
            div_zero_o  => OPEN, -- divide by zero
            inf_o       => OPEN, -- infinity
            zero_o      => OPEN, -- zero
            qnan_o      => OPEN, -- queit Not-a-Number
            snan_o      => OPEN  -- signaling Not-a-Number
        );

    END GENERATE GEN_MULTIPLY;
    GEN_ADD : FOR i IN 0 TO 2 GENERATE
        fpu_Inst : fpu
        PORT MAP(
            clk_i    => CLK,
            opa_i    => opa_i_add_array(i),
            opb_i    => opb_i_add_array(i),
            fpu_op_i => "000", -- add
            rmode_i  => "00",  -- 00 = round to nearest even(default), 

            -- Output port   
            output_o => output_o_add_array(i),

            -- Control signals
            start_i => start_add_i(i), -- is also restart signal
            ready_o => ready_add_o(i),

            -- Exceptions
            ine_o       => OPEN, -- inexact
            overflow_o  => OPEN, -- overflow
            underflow_o => OPEN, -- underflow
            div_zero_o  => OPEN, -- divide by zero
            inf_o       => OPEN, -- infinity
            zero_o      => OPEN, -- zero
            qnan_o      => OPEN, -- queit Not-a-Number
            snan_o      => OPEN  -- signaling Not-a-Number
        );
    END GENERATE GEN_ADD;
END Behavioral;