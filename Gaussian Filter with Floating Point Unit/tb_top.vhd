----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/10/2021 11:46:46 PM
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

    COMPONENT top IS
        PORT (
            CLK                : IN STD_LOGIC;
            filter_valid       : IN STD_LOGIC;
            filter_data_i      : IN MemType2D(0 TO 4);
            filter_data_o      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            filter_ready       : OUT STD_LOGIC;
            filteredPixelReady : OUT STD_LOGIC
        );
    END COMPONENT;

    SIGNAL doutGolden : STD_LOGIC_VECTOR(31 DOWNTO 0)        := (OTHERS => '0');

    PROCEDURE FILTERDATA (
        FILE RawImageHex_file : text;
        SIGNAL CLK            : IN STD_LOGIC;
        SIGNAL filter_valid   : OUT STD_LOGIC;
        SIGNAL filter_data_i  : OUT MemType2D(0 TO 4);
        SIGNAL filter_ready   : IN STD_LOGIC
    ) IS
        VARIABLE RawImageHex_current_line  : line;
        VARIABLE RawImageHex_current_field : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    BEGIN
        FOR i IN 0 TO 4 LOOP
            WAIT UNTIL falling_edge(CLK);
            readline(RawImageHex_file, RawImageHex_current_line);
            hread(RawImageHex_current_line, RawImageHex_current_field);
            filter_data_i (0) <= RawImageHex_current_field;

            readline(RawImageHex_file, RawImageHex_current_line);
            hread(RawImageHex_current_line, RawImageHex_current_field);
            filter_data_i (1) <= RawImageHex_current_field;

            readline(RawImageHex_file, RawImageHex_current_line);
            hread(RawImageHex_current_line, RawImageHex_current_field);
            filter_data_i (2) <= RawImageHex_current_field;

            readline(RawImageHex_file, RawImageHex_current_line);
            hread(RawImageHex_current_line, RawImageHex_current_field);
            filter_data_i (3) <= RawImageHex_current_field;

            readline(RawImageHex_file, RawImageHex_current_line);
            hread(RawImageHex_current_line, RawImageHex_current_field);
            filter_data_i (4) <= RawImageHex_current_field;

            WAIT UNTIL falling_edge(CLK);
            filter_valid <= '1';
            WAIT UNTIL falling_edge(CLK);
            filter_valid <= '0';
            WAIT UNTIL filter_ready = '1';
        END LOOP;
    END PROCEDURE;

    SIGNAL CLK                : STD_LOGIC         := '1';
    SIGNAL filter_valid       : STD_LOGIC         := '0';
    SIGNAL filter_data_i      : MemType2D(0 TO 4) := (OTHERS => (OTHERS => '0'));
    SIGNAL filter_data_o      : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL filter_ready       : STD_LOGIC;
    SIGNAL filteredPixelReady : STD_LOGIC := '0';

    SIGNAL Diff           : INTEGER := 0;
    SIGNAL addrGoldenCntr : INTEGER := 0;

    SIGNAL denemeSignal : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
BEGIN
    CLK <= NOT CLK AFTER 5 ns;
    dut : PROCESS
        VARIABLE GoldenResult_file_current_line : line;
        FILE RawImageHex_file                   : text OPEN read_mode IS "C:\Users\Muhammed\OneDrive\FPGA_Projects\GaussianFilter\GaussianFilter.srcs\sim_1\new\ImageRawArrayHex.txt";
        FILE GoldenResult_file                  : text OPEN read_mode IS "C:\Users\Muhammed\OneDrive\FPGA_Projects\GaussianFilter\GaussianFilter.srcs\sim_1\new\GoldenImageHex.txt";
        FILE test_vector                        : text OPEN write_mode IS "C:\Users\Muhammed\OneDrive\FPGA_Projects\GaussianFilter\GaussianFilter.srcs\sim_1\new\filteredImageHex.txt";
        VARIABLE row                            : line;
        VARIABLE GoldenData_current_field       : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    BEGIN
        WHILE NOT endfile(GoldenResult_file) LOOP
            FILTERDATA(RawImageHex_file, CLK, filter_valid, filter_data_i, filter_ready);
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
    top_Inst : top
    PORT MAP(
        CLK                => CLK,
        filter_valid       => filter_valid,
        filter_data_i      => filter_data_i,
        filter_data_o      => filter_data_o,
        filter_ready       => filter_ready,
        filteredPixelReady => filteredPixelReady
    );

END Behavioral;