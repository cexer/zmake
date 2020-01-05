@ECHO OFF
premake5.exe --projdir="%cd%" --file="%cd%\zmake.lua" --systemscript="%~dp0zmakefuns.lua" %*