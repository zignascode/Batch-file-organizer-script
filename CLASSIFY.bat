@echo off
setlocal enableextensions EnableDelayedExpansion
for /f %%a in ('copy /Z "%~dpf0" nul') do set "CR=%%a"
chcp 65001 >nul

ECHO. & ECHO	_______________________________________________
ECHO	_______________________________________________
ECHO		FILES CLASSIFIER BY YEAR V.1.0 25/03/2026
ECHO		Author: B.M.F. (https://github.com/zignascode)
ECHO	_______________________________________________
ECHO	_______________________________________________ & ECHO.

REM PARTE 1. Configura la carpeta de resultados
::###########################################################################################
echo Todos tus archivos contenidos en la carpeta actual serán
echo clasificados de acuerdo al año en el que fueron modificados
echo por última vez, a excepción de casos especiales, la mayoría
echo de las veces esta fecha coincide con la fecha de creación.
ECHO.
echo Para empezar, coloca el nombre de la carpeta de resultados

:AGAIN
set /p "fres=Nombre: " & ECHO.
if exist %fres% (
	set /p "resp=Ya existe una carpeta con este nombre, cambiar nombre? <s/n>: "
	if /i !resp!==s GOTO AGAIN
	if /i !resp!==n GOTO CONTINUE
)
mkdir %fres% || (echo Introduce un valor válido & GOTO AGAIN)

:CONTINUE
echo Se ha establecido con éxito la carpeta .../%fres%
REM set csv=%fres%/csv_file.CSV

REM PARTE 2. Realiza un conteo preliminar de los archivos
::###########################################################################################
echo Ejecutando conteo preliminar... & ECHO.
set "total=0" & set "other=0" & set "lext="
for %%n in (*.*) do (
	set /a "total=!total!+1"
	::Verifica si existe una variable nombrada con la extensión.
	if not defined %%~xn (
		::Se define por primera vez, si falla es un archivo sin extensión.
		set "%%~xn=1" 2>nul || set /a "other=!other!+1"
		set "lext=!lext!%%~xn " ::Guarda en un array la extensión definida.
	) else (
		::Si ya está definida, suma 1 al conteo de la variable correspondiente.
		set /a "%%~xn=!%%~xn!+1"
	)
)

::Imprime el listado resultante de extensiones con su conteo.
for %%x in (!lext!) do (echo 	 %%x: !%%x!)
echo 	others: !other! & ECHO.
echo 	Total: !total! & ECHO. & timeout /t 1 /nobreak >nul & pause
echo 	Procesando archivos ... & ECHO.

::Crea un archivo con el siguiente encabezado (silenciado temporalmente).
REM echo NAME_FILE,SIZE_BYTES,EXTENSION,LD_MODIFY,HASHFILE> %csv%

REM PARTE 3. Ciclo principal para obtener y guardar datos de cada archivo.
::###########################################################################################
set "count=0" ::El número de iteración
set "reset=0" ::Controla la periodicidad del cálculo de estimaciones.

::Recorre todos los archivos contenidos en la carpeta actual.
for %%i in (*.*) do (
	::Obtiene el time inicial para estimación.
	if !reset! EQU 0 (
		for /f "tokens=1-4 delims=:." %%a in ("!time!") do (
		::Del comando time extrae los centisegundos totales.
		::Se usa 1%%-100 para evitar problemas con el formato de hora de un solo dígito.
		set /a "to = ((1%%a-100)*360000)+((1%%b-100)*6000)+((1%%c-100)*100)+1%%d-100"
		)
	)
	::Ignora este archivo en el ciclo.
	if %%i NEQ CLASSIFY.bat (

		::Obtiene la última fecha de modificación con el modificador %%~t.	
		set tw=%%~ti
		set "year=!tw:~6,4!" & set "month=!tw:~3,2!" & set "day=!tw:~0,2!"
		set "fm=!year!!month!!day!"

		::Obtiene el hashfile único del archivo del comando certutil.
		::El comando certutil devuelve varias líneas, se salta la primera y se guarda la segunda.
		set x=1
		for /F "skip=1" %%h in ('certutil -hashfile "%%i" MD5') do (
			if !x! EQU 1 (set "hash=%%h" & set x=0)
		)

		::Obtiene la extensión del archivo y define el nombre nuevo.
		set ext=%%~xi & set ext=!ext:~1,-1!
		set "rename=!fm!_!hash:~-10!%%~xi"
		set "dest=%fres%/!year!/!rename!"

		::Verifica que no exista el archivo nuevo y lo mueve a la carpeta de su año.
		if not exist !dest! (
			move "%%i" !dest! >nul 2>&1 || (
				::Estas líneas se ejecutan si falla el movimiento.
				mkdir "%fres%/!year!" 2>nul
				move "%%i" !dest! >nul 2>&1 || (
					::Esta línea se ejecuta si falla el comando por caracteres especiales.
					move "%%i" >nul 2>&1 %fres% & endlocal
				)
			)
		) else (
			::Si hay duplicados, se dirije a COPIADO.
			call :COPIADO "%%i" "!rename!"
		)
		::Guarda los datos en el archivo CSV (silenciado temporalmente).
		REM !rename!,%%~zi,!ext!,!tw!,!hash!>> %csv%
	)
	::Actualiza los contadores.
	set /a "reset=!reset!+1" & set /a "count=!count!+1"
	set /a "avance=(!count!*100/!total!)"

	::Obtiene el time final cada 10 iteraciones.
	if !reset! EQU 10 (
	 	for /f "tokens=1-4 delims=:." %%a in ("!time!") do (
		set /a "tf = ((1%%a-100)*360000)+((1%%b-100)*6000)+((1%%c-100)*100)+1%%d-100"
		)
		::Obtiene el estimado de tiempo restante y le da formato.
		set /a "durp=(!tf!-!to!)/10" & set /a "trest=!durp!*(!total!-!count!)"
		set /a "hr=!trest!/360000!"
		set /a "mr=(!trest! %% 360000)/6000"
		set /a "sr=((!trest! %% 360000) %% 6000)/100"
		set "reset=0" ::Reinicia el ciclo de estimación cada 10 iteraciones.
	)
	::Imprime el avance en la terminal.
	<nul set /p "=|	[!count!/!total!]...!avance!%% Tiempo Restante: !hr!hrs:!mr!min:!sr!seg !CR!"
)
ECHO. & echo Finalizado, presione cualquier tecla para cerrar & pause >nul
exit /b

REM SUBRUTINA 1 EXTERNA PARA TRABAJAR LAS COPIAS SIN ROMPER EL CICLO PRINCIPAL
::###########################################################################################
:COPIADO
::Toma los parámetros del archivo original y el nombre nuevo para las copias (línea 108).
set "file=%~1" & set "cfile=%~2"
set "cn=C1" & set "n=1" ::Prefijos de archivos duplicados

:RECOUNT
::Si el nombre nuevo ya existe, suma 1 al contador y cambia el prefijo.
set "nfile=!cn!_!cfile!"
if not exist copies/!nfile! (
	::Si la copia no existe, se mueve el archivo a la carpeta de copias con el nuevo nombre.
	move "!file!" copies/!nfile! >nul 2>&1 || (
		::Si la carpeta de copias no existe, se crea y se mueve el archivo.
		mkdir copies & move "!file!" copies/!nfile! >nul 2>&1
	)
) else (
	::Si la copia ya existe, se repite el proceso hasta encontrar un nombre disponible.
	set /a "n=!n!+1" & set "cn=C!n!"
	GOTO RECOUNT
)
exit /b

REM NOTAS
::###########################################################################################
REM NOTA 1: LA FECHA DE CREACIÓN DE LAS COPIAS ES LA MISMA QUE LA FECHA DE COPIADO
REM NOTA 2: %%~ti ESTE MODIFICADOR MUESTRA LA FECHA DE MODIFICACIÓN CON HORA
REM NOTA 3: Alterntaiva para fecha de modificación
REM for /F %%b in ('dir "%%i" /T:W ^| findstr /R "^[0-9]"') do (set tw=%%b)