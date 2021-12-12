----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Muhammed KOCAOGLU
-- 
-- Create Date: 12/12/2021 03:02:23 PM
-- Design Name: Gaussian Filter
-- Module Name: GaussianFilter - Behavioral
-- Project Name: Gaussian Filter
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
----------------------------------------------------------------------------------

LIBRARY ieee;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

PACKAGE my_data_types IS
    TYPE MemType2D8 IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
    TYPE MemType2D16 IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    TYPE MemType2D32 IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
    TYPE MemType3D8 IS ARRAY (INTEGER RANGE <>) OF MemType2D8(0 TO 4);
    TYPE MemType3D16 IS ARRAY (INTEGER RANGE <>) OF MemType2D16(0 TO 4);
    TYPE MemType3D32 IS ARRAY (INTEGER RANGE <>) OF MemType2D32(0 TO 4);

    FUNCTION "+" (L : MemType2D16; R : MemType2D16) RETURN MemType2D16;
END PACKAGE my_data_types;
-- didn't work. try again later. 
PACKAGE BODY my_data_types IS
    FUNCTION "+" (
        L : IN MemType2D16;
        R : IN MemType2D16
    )
        RETURN MemType2D16 IS
        VARIABLE res : MemType2D16(0 TO 4);
    BEGIN
        FOR i IN 0 TO 4 LOOP
            res(i) := L(i) + R(i);
            RETURN res;
        END LOOP;
    END;

END PACKAGE BODY my_data_types;
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.my_data_types.ALL; -- user-defined package
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY GaussianFilter IS
    PORT (
        CLK                : IN STD_LOGIC;
        filter_valid       : IN STD_LOGIC;
        filter_data_i      : IN MemType3D8(0 TO 4);
        filter_data_o      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        filteredPixelReady : OUT STD_LOGIC
    );
END GaussianFilter;

ARCHITECTURE Behavioral OF GaussianFilter IS
    SIGNAL output_o_Add3Darray        : MemType3D32(0 TO 3) := (OTHERS => (OTHERS => (OTHERS => '0')));
    SIGNAL output_o_Add3Darray_Layer2 : MemType3D32(0 TO 1) := (OTHERS => (OTHERS => (OTHERS => '0')));
    SIGNAL output_o_Add3Darray_Layer3 : MemType2D32(0 TO 5) := (OTHERS => (OTHERS => '0'));
    SIGNAL output_o_Add3Darray_Layer4 : MemType2D32(0 TO 3) := (OTHERS => (OTHERS => '0'));
    SIGNAL output_o_Add3Darray_Layer5 : MemType2D32(0 TO 1) := (OTHERS => (OTHERS => '0'));
    SIGNAL output_o_Mul3Darray        : MemType3D16(0 TO 5) := (OTHERS => (OTHERS => (OTHERS => '0')));
    
    CONSTANT gaussian_coeff           : MemType3D8(0 TO 4)  := (-- extended by 4096
    (x"97", x"A0", x"A4", x"A0", x"97"),
    (x"A0", x"AA", x"AE", x"AA", x"A0"),
    (x"A4", x"AE", x"B1", x"AE", x"A4"),
    (x"A0", x"AA", x"AE", x"AA", x"A0"),
    (x"97", x"A0", x"A4", x"A0", x"97"));

    TYPE states IS (
        S_IDLE,
        S_MUL,
        S_ADD_STAGE
    );
    SIGNAL state : states := S_IDLE;

    SIGNAL cntr           : INTEGER   := 0;

    SIGNAL filter_data_o_Reg : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');

BEGIN

    P_MAIN : PROCESS (CLK)
    BEGIN
        IF rising_edge(CLK) THEN
            filteredPixelReady <= '0';
            CASE state IS
                WHEN S_IDLE =>
                    IF filter_valid = '1' THEN
                        state <= S_MUL;
                    END IF;

                WHEN S_MUL => -- multiplication is performed in single cycle
                    FOR i IN 0 TO 4 LOOP
                        FOR j IN 0 TO 4 LOOP
                            output_o_Mul3Darray(i)(j) <= gaussian_coeff(i)(j) * filter_data_i(i)(j);
                            state                     <= S_ADD_STAGE;
                        END LOOP;
                    END LOOP;


                WHEN S_ADD_STAGE =>
                    FOR i IN 0 TO 4 LOOP
                        FOR j IN 0 TO 2 LOOP
                            output_o_Add3Darray(j)(i) <= (x"0000" & output_o_Mul3Darray(j * 2)(i)) + (x"0000" & output_o_Mul3Darray(j * 2 + 1)(i));
                        END LOOP;
                    END LOOP;

                    FOR i IN 0 TO 4 LOOP
                        FOR j IN 0 TO 1 LOOP
                            output_o_Add3Darray_Layer2(j)(i) <= output_o_Add3Darray(j * 2)(i) + output_o_Add3Darray(j * 2 + 1)(i);
                        END LOOP;
                    END LOOP;

                    FOR i IN 0 TO 4 LOOP
                        output_o_Add3Darray_Layer3(i) <= output_o_Add3Darray_Layer2(0)(i) + output_o_Add3Darray_Layer2(1)(i);
                    END LOOP;

                    FOR i IN 0 TO 2 LOOP
                        output_o_Add3Darray_Layer4(i) <= output_o_Add3Darray_Layer3(i * 2) + output_o_Add3Darray_Layer3(i * 2 + 1);
                    END LOOP;

                    FOR i IN 0 TO 1 LOOP
                        output_o_Add3Darray_Layer5(i) <= output_o_Add3Darray_Layer4(i * 2) + output_o_Add3Darray_Layer4(i * 2 + 1);
                    END LOOP;

                    filter_data_o_Reg <= output_o_Add3Darray_Layer5(0) + output_o_Add3Darray_Layer5(1);

                    IF cntr = 6 THEN
                        state              <= S_IDLE;
                        filteredPixelReady <= '1';
                        cntr               <= 0;
                    ELSE
                        cntr <= cntr + 1;
                    END IF;


            END CASE;
        END IF;
    END PROCESS;
    filter_data_o <=    filter_data_o_Reg;
END Behavioral;