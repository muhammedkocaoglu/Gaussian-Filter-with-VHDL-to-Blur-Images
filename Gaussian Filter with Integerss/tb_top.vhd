----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Muhammed KOCAOGLU
-- 
-- Create Date: 12/12/2021 03:25:39 PM
-- Design Name: 
-- Module Name: tb_top - Behavioral
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
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE std.textio.ALL;
USE IEEE.STD_LOGIC_TEXTIO.ALL;
USE work.my_data_types.ALL; -- user-defined package

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY tb_top IS
END tb_top;
ARCHITECTURE Behavioral OF tb_top IS

    COMPONENT GaussianFilter IS
        PORT (
            CLK                : IN STD_LOGIC;
            filter_valid       : IN STD_LOGIC;
            filter_data_i      : IN MemType3D8(0 TO 4);
            filter_data_o      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            filteredPixelReady : OUT STD_LOGIC
        );
    END COMPONENT;

    PROCEDURE FILTERDATA (
        FILE RawImageHex_file : text;
        SIGNAL CLK            : IN STD_LOGIC;
        SIGNAL filter_valid   : OUT STD_LOGIC;
        SIGNAL filter_data_i  : OUT MemType3D8(0 TO 4)
    ) IS
        VARIABLE RawImageHex_current_line  : line;
        VARIABLE RawImageHex_current_field : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    BEGIN
        WAIT UNTIL falling_edge(CLK);
        for i in 0 to 4 loop 
            for j in 0 to 4 loop 
                readline(RawImageHex_file, RawImageHex_current_line);
                hread(RawImageHex_current_line, RawImageHex_current_field);
                filter_data_i (i)(j) <= RawImageHex_current_field;
            end loop;
        end loop;

        WAIT UNTIL falling_edge(CLK);
        filter_valid <= '1';
        WAIT UNTIL falling_edge(CLK);
        filter_valid <= '0';

    END PROCEDURE;


    SIGNAL CLK                : STD_LOGIC                     := '1';
    SIGNAL filter_valid       : STD_LOGIC                     := '0';
    SIGNAL filter_data_i      : MemType3D8(0 TO 4)            := (OTHERS => (OTHERS => (OTHERS => '0')));
    SIGNAL filter_data_o      : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL filteredPixelReady : STD_LOGIC                     := '0';

    SIGNAL Diff           : INTEGER := 0;
    SIGNAL addrGoldenCntr : INTEGER := 0;
    SIGNAL doutGolden : STD_LOGIC_VECTOR(31 DOWNTO 0)        := (OTHERS => '0');

BEGIN

    CLK <= NOT CLK AFTER 5 ns;

    dut : PROCESS
        VARIABLE GoldenResult_file_current_line : line;
        FILE RawImageHex_file                   : text OPEN read_mode IS "C:\Users\Muhammed\OneDrive\FPGA_Projects\GaussianFilterExtendedCoeff\GaussianFilterExtendedCoeff.srcs\sim_1\new\ImageRawArrayHex.txt";
        FILE GoldenResult_file                  : text OPEN read_mode IS "C:\Users\Muhammed\OneDrive\FPGA_Projects\GaussianFilterExtendedCoeff\GaussianFilterExtendedCoeff.srcs\sim_1\new\GoldenImageHexVec.txt";
        FILE test_vector                        : text OPEN write_mode IS "C:\Users\Muhammed\OneDrive\FPGA_Projects\GaussianFilterExtendedCoeff\GaussianFilterExtendedCoeff.srcs\sim_1\new\filteredImageHex.txt";
        VARIABLE row                            : line;
        VARIABLE GoldenData_current_field       : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    BEGIN
       WHILE NOT endfile(RawImageHex_file) LOOP
            FILTERDATA(RawImageHex_file, CLK, filter_valid, filter_data_i);
            WAIT UNTIL filteredPixelReady = '1';

            readline(GoldenResult_file, GoldenResult_file_current_line);
            hread(GoldenResult_file_current_line, GoldenData_current_field);
            doutGolden <= GoldenData_current_field;

            WAIT UNTIL falling_edge(CLK);
            WAIT UNTIL falling_edge(CLK);
            Diff <= ABS(conv_integer(GoldenData_current_field) - conv_integer(filter_data_o));
            WAIT UNTIL falling_edge(CLK);
            hwrite(row, filter_data_o);
            writeline(test_vector, row);

            REPORT "The index of data is " & INTEGER'image(addrGoldenCntr);
            ASSERT Diff < 4 OR GoldenData_current_field = x"00000000"
            REPORT "Diff must be smaller than 3"
                SEVERITY failure;

            addrGoldenCntr <= addrGoldenCntr + 1;

        END LOOP;

        file_close(test_vector);
        file_close(RawImageHex_file);
        file_close(GoldenResult_file);
        WAIT FOR 50 ns;
        REPORT "Simulation completed successfully.";
        std.env.finish;
    END PROCESS;

    GaussianFilter_Inst : GaussianFilter
    PORT MAP(
        CLK                => CLK,
        filter_valid       => filter_valid,
        filter_data_i      => filter_data_i,
        filter_data_o      => filter_data_o,
        filteredPixelReady => filteredPixelReady
    );

END Behavioral;