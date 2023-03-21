----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:12:11 04/04/2014 
-- Design Name: 
-- Module Name:    memoriaRAM - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
-- Memoria RAM de 128 oalabras de 32 bits
entity Data_Memory_Subsystem is port (
		  CLK : in std_logic;
		  reset: in std_logic; 
		  ADDR : in std_logic_vector (31 downto 0); --Dir solicitada por el Mips
          Din : in std_logic_vector (31 downto 0);--entrada de datos desde el Mips
		  WE : in std_logic;		-- write enable	del MIPS
		  RE : in std_logic;		-- read enable del MIPS	
		  IO_input: in std_logic_vector (31 downto 0); --dato que viene de una entrada del sistema. En esta memoria no se usa
		  Mem_ready: out std_logic; -- indica si podemos hacer la operación solicitada en el ciclo actual. En esta memoria vale siempre '1'.
		  Data_abort: out std_logic; --indica que el último acceso a memoria ha sido un error
		  Dout : out std_logic_vector (31 downto 0) --dato que se envía al Mips
		  );
end Data_Memory_Subsystem;

architecture Behavioral of Data_Memory_Subsystem is
type RamType is array(0 to 127) of std_logic_vector(31 downto 0);
signal RAM : RamType := (  			X"00000100", X"00000001", X"00000008", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 0,1,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 8,9,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 16,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 24,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 32,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 40,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 48,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 56,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000",  --word 64,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 72,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 80,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 88,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 96,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 104,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", --word 112,...
									X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000", X"00000000");--word 120,...
signal dir_7:  std_logic_vector(6 downto 0); 
signal unaligned, out_of_range:  std_logic;
begin
 
 dir_7 <= ADDR(8 downto 2); -- como la memoria es de 128 plalabras no usamos la dirección completa sino sólo 7 bits. Como se direccionan los bytes, pero damos palabras no usamos los 2 bits menos significativos
 process (CLK)
    begin
        if (CLK'event and CLK = '1') then
            if (WE = '1') then -- sólo se escribe si WE vale 1
                RAM(conv_integer(dir_7)) <= Din;
            end if;
        end if;
    end process;

    Dout <= RAM(conv_integer(dir_7)) when (RE='1') else "00000000000000000000000000000000"; --sólo se lee si RE vale 1
    --------------------------------------------------------------------------------------------------------------------
    -- MEMORY READY
    --------------------------------------------------------------------------------------------------------------------
    -- esta memoria está siempre disponible, y no genera ningún retardo adicional, por eso Mem_ready es un '1' siempre.
    Mem_ready <= '1';
    --------------------------------------------------------------------------------------------------------------------
    -- DATA ABORT
    --------------------------------------------------------------------------------------------------------------------
    -- out_of_range se activa si la dirección está fuera del rango. La memoria es 128 palabras empezando en la dirección 0. Si pedimos una dirección mayor saltará el abort
    out_of_range <= '0' when (ADDR(31 downto 9)= "00000000000000000000000") else '1';
    -- Sólo vamos a permitir direcciones alineadas. Como leemos palabras de 4 bytes estas deben estar en direcciones múltiplos de 4. Es decir, acaban en "00"
    unaligned <= '0' when (ADDR(1 downto 0)= "00") else '1';
    -- Hay un data abort cuando se accede a una dirección que no existe, o se realiza un acceso no alineado.
    -- ¡Pero sólo si se está haciendo un acceso a memoria! Si WE y RE valen cero no se está accediendo a memoria, por tanto da igual el valor de la dirección
    Data_abort <= (out_of_range or unaligned) and (WE or RE);

end Behavioral;

