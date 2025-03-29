::@ECHO OFF
::projdir MUST NOT endswith \
premake5.exe --projdir="%cd%" --file="%cd%\zmake.lua" --systemscript="%~dp0zmakefuns.lua" --scripts="%~dp0..\src\premake-core" --debugger %*