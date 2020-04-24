@ECHO OFF
premake5dbg.exe --projdir="%cd%" --systemscript="%~dp0zmakeinit.lua" --scripts="%~dp0..\premake-core" --debugger %*