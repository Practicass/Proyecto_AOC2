library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--Mux 4 a 1
entity UD is
    Port ( 	
			valid_I_ID : in  STD_LOGIC; --indica si es una instrucción de ID es válida
			valid_I_EX : in  STD_LOGIC; --indica si es una instrucción de EX es válida
			valid_I_MEM : in  STD_LOGIC; --indica si es una instrucción de MEM es válida
    		Reg_Rs_ID: in  STD_LOGIC_VECTOR (4 downto 0); --registros Rs y Rt en la etapa ID
		  	Reg_Rt_ID	: in  STD_LOGIC_VECTOR (4 downto 0);
			MemRead_EX	: in std_logic; -- informaciÃ³n sobre la instrucciÃ³n en EX (destino, si lee de memoria y si escribe en registro)
			RegWrite_EX	: in std_logic;
			RW_EX			: in  STD_LOGIC_VECTOR (4 downto 0);
			RegWrite_Mem	: in std_logic;-- informacion sobre la instruccion en Mem (destino y si escribe en registro)
			RW_Mem			: in  STD_LOGIC_VECTOR (4 downto 0);
			IR_op_code	: in  STD_LOGIC_VECTOR (5 downto 0); -- cÃ³digo de operaciÃ³n de la instrucciÃ³n en IEEE
         	salto_tomado			: in std_logic; -- 1 cuando se produce un salto 0 en caso contrario
         	--Nuevo
         	Mem_ready: in std_logic; -- 1 cuando la memoria puede realizar la operación solicitada en el ciclo actual
			parar_EX: out  STD_LOGIC; -- Indica que las etapas EX y previas deben parar
         	Kill_IF		: out  STD_LOGIC; -- Indica que la instrucción en IF no debe ejecutarse (fallo en la predicción de salto tomado)
			Parar_ID		: out  STD_LOGIC -- Indica que las etapas ID y previas deben parar
			); 
end UD;
Architecture Behavioral of UD is
signal dep_rs_EX, dep_rs_Mem, dep_rt_EX, dep_rt_Mem, ld_uso_rs, ld_uso_rt, WRO_rs, BEQ_rs, BEQ_rt, riesgo_datos_ID, parar_EX_internal : std_logic;
CONSTANT NOP : STD_LOGIC_VECTOR (5 downto 0) := "000000";
CONSTANT LW : STD_LOGIC_VECTOR (5 downto 0) := "000010";
CONSTANT BEQ : STD_LOGIC_VECTOR (5 downto 0) := "000100";
CONSTANT RTE_opcode : STD_LOGIC_VECTOR (5 downto 0) := "001000";
CONSTANT WRO_opcode : STD_LOGIC_VECTOR (5 downto 0) := "100000";
begin
-------------------------------------------------------------------------------------------------------------------------------
-- Kill_IF:
-- da la orden de matar la instrucción que se ha leído en Fetch
-- Se debe activar cada vez que se salte (entrada salto_tomado), ya que por defecto se ha hecho el fetch de la instrucción siguiente al salto y si se salta no hay que ejecutarla
-- IMPORTANTE: 
-- 	* si un beq no tiene sus operandos disponibles no sabe si debe saltar o no. Da igual lo que diga salto tomado, ya que se ha calculado con datos incorrectos
-- 	* si la instrucción que hay en ID no es válida hay que ignorarla cuando si nos dice que va a saltar (igual que si nos dice cualuier otra cosa), sólo hacmeos caso a las instrucciones válidas
-- Completar: activar Kill_IF cuando proceda
	Kill_IF <= '1' when (salto_tomado = '1' and valid_I_ID ='1') or ((IR_op_code = BEQ) and (((RegWrite_EX ='1') and (RW_EX = Reg_Rs_ID or  RW_EX = Reg_Rt_ID)) or (RegWrite_Mem = '1' and (RW_MEM = Reg_Rs_ID or RW_MEM = Reg_Rt_ID)))) else '0';
-------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
-- Detección de dependencias de datos:	
-- El código incluye un ejemplo: dep_rs_EX. Debéis completar el resto de opciones.	
	
	-- dep_rs_EX: la I en EX escribe en el registro rs y la I en ID usa rs (es decir no es un NOP ni RTE)
	dep_rs_EX 	<= '1' when ((valid_I_EX = '1') AND (Reg_Rs_ID = RW_EX) and (RegWrite_EX = '1') and (IR_op_code /= NOP) and (IR_op_code /= RTE_opcode))	else '0';
								
	------------------------------------------------------------------------------------
	-- Completar. Falta la lógica que genera el valor correcto de estas señales.
	-- dep_rs_Mem: 
	dep_rs_Mem	<= 	'1' when ((valid_I_MEM = '1') AND (Reg_Rs_ID = RW_Mem) and (RegWrite_Mem = '1') and (IR_op_code /= NOP) and (IR_op_code /= RTE_opcode)) else '0';
							
	-- dep_rt_EX: 
	dep_rt_EX	<= 		'1' when ((valid_I_EX = '1') AND (Reg_Rt_ID = RW_EX) and (RegWrite_EX = '1') and (IR_op_code /= NOP) and (IR_op_code /= RTE_opcode)) else '0';
								
	-- dep_rt_Mem:
	dep_rt_Mem	<= 	'1' when ((valid_I_MEM = '1') AND (Reg_Rt_ID = RW_Mem) and (RegWrite_Mem = '1') and (IR_op_code /= NOP) and (IR_op_code /= RTE_opcode)) else '0';
-------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
-- Riesgos de datos:
	-- 1) lw_uso: Si hay dependencia y la instrucción en EX es lw tenemos un lw_uso
	ld_uso_rs <= 	dep_rs_EX;
	ld_uso_rt <= 	dep_rt_EX;
									
	-- 2) BEQ: si hay dependencias y la I en ID es un BEQ es un riesgo porque el BEQ lee los datos en ID, y no tenemos red de cortos en esa etapa
	BEQ_rs	<= 	dep_rs_EX and dep_rs_Mem;
	BEQ_rt	<= 	dep_rt_EX and dep_rt_Mem;
		
	-- 3) WRO: Dependencia similar al BEQ, pero hay que tener en cuenta que WRO sólo usa Rs
	
	WRO_rs	<= 	dep_rs_EX and dep_rs_Mem;
	
	-- Si se cumple alguna de las condiciones de riesgo de datos se detienen las etapas IF e ID
	riesgo_datos_ID <= BEQ_rt OR BEQ_rs OR ld_uso_rs OR ld_uso_rt OR WRO_rs;
	-- IMPORTANTE: sólo hay riesgos de datos si la instrucción en ID es válida
	-- Si se da la orden de parar EX, también hay que parar ID. En el proyecto 1 no hace falta, pero lo ponemos para no tener que tocarlo luego
	Parar_ID <= parar_EX_internal or (valid_I_ID and riesgo_datos_ID);
-------------------------------------------------------------------------------------------------------------------------------
-- Parar_EX:
-- NOTA: en el proyecto 1, no hace falta parar nunca en EX porque la memoria siempre está preparada para hacer lo que le pidas
-- En el P2, habrá que mirar Mem_ready y si no puede hacer lo que le has pedido (Mem_ready = '0') parar la etapa EX y las anteriores
-- parar_EX_internal se define para poder leerla en el código (en vhdl las salidas de una entidad no se pueden leer dentro de la entidad. 
-- Depende de cómo lo hagáis es necesaria o no

	parar_EX_internal <= '0';
	parar_EX <= parar_EX_internal;
-------------------------------------------------------------------------------------------------------------------------------
end Behavioral;


