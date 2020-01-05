@ECHO OFF
premake5dbg.exe --projdir="%cd%" --file="%cd%\zmake.lua" --systemscript="%~dp0zmakefuns.lua" --scripts=F:\develop\project\tools\premake-core --debugger %*