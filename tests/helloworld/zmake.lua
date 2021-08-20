library("zbase", function()
	includedirs {"E:/Workspace/projects/zc/zion/include"}
	libdirs {"E:/Workspace/projects/zc/zion/lib/{os}-{arch}"}
	links {"zbase{-cc}{-sd}"}
	
	depends { "pugixml" }
	if os.target() == "windows" then
		depends { "shlwapi", "shell32", "stb" }
		linkoptions {"/FORCELINK"}
	end
	if os.target() == "macosx" then
		depends { "Cocoa.framewokr" }
	end
	if os.target() == "linux" then
		linkoptions { "pkg-config --cflags --libs gtk+-2.0" }
	end
	
	postbuildcmds {
		{
			exec = "copy",
			filter = {"kind:WindowedApp or ConsoleApp", "dll-*"},
			from = "{libdir}/{dllprefix}zbase{-cc}{-sd}{.dll}"
		}
	}
end)

solution("helloworld", function()
	project("helloworld", function()
		category ("CONSOLE")
		directory("src")
		depends {"zbase"}
	end);
end);
