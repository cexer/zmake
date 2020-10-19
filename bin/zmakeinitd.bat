@ECHO OFF
premake5.exe --projdir="%cd%" --systemscript="%~dp0zmakeinit.lua" --scripts="%~dp0..\premake-core" --debugger %*