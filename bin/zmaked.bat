::@ECHO OFF
premake5dbg.exe --projdir="%cd%" --file="%cd%\zmake.lua" --systemscript="%~dp0zmakefuns.lua" --scripts="%~dp0..\src\premake-core" --debugger %*