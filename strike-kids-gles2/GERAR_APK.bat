@echo off
setlocal
cd /d "%~dp0"
title Strike Kids (OpenGL ES 2.0) - Gerar APK
rem Gera o APK da TV Box da EDICAO OPENGL ES 2.0 (Godot 3.6.3, Mali-400/450):
rem mostra cada passo nesta janela e guarda o historico em
rem build\android\GERACAO-COMPLETA.log. Opcoes (opcionais):
rem   GERAR_APK.bat -Giro -1         (topo do jogo na direita do HDMI)
rem   GERAR_APK.bat -Giro 0          (TV deitada, sem giro)
rem   GERAR_APK.bat -Instalar        (instala na TV Box pelo adb)
rem   GERAR_APK.bat -TelaInicial     (instala e o jogo abre sozinho ao ligar a TV)
rem   GERAR_APK.bat -Versao 5.7-gles2
if exist "%~dp0project.godot" goto projeto_ok
echo.
echo ERRO: extraia o ZIP inteiro antes e rode o GERAR_APK.bat de dentro
echo da pasta strike-kids-gles2 (junto do arquivo project.godot).
echo.
pause
exit /b 1
:projeto_ok
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GERAR_APK.ps1" %*
set "RESULTADO=%ERRORLEVEL%"
echo.
if "%RESULTADO%"=="0" goto sucesso
echo ============================================================
echo  NAO FOI POSSIVEL GERAR O APK. Envie o arquivo:
echo  build\android\GERACAO-COMPLETA.log
echo ============================================================
goto fim
:sucesso
echo ============================================================
echo  PRONTO: APK-Pronto\StrikeKids_GLES2.apk
echo ============================================================
:fim
echo.
pause
exit /b %RESULTADO%
