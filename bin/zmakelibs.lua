--print("prelibs.lua");

-- Global variables
_LIBRARIES = _LIBRARIES or {}; -- predefined libraries

function library(name, lib)
	_LIBRARIES[name] = lib;
end


library("boost", {
    includedirs = {
        "F:/develop/library/boost_1_61_0"
    },
    libdirs = {
		"F:/develop/library/boost_1_61_0/link"
    }
});

--[[
library("qbase", {
	includedirs = {
		"${QFRAMEWORK3}/include"
	},
	libdirs = {"${QFRAMEWORK3}/lib/{system}-{arch}"},
	links = {"qbase{suffix}{.lib}"},
	postbuildcmds = {
		{
			exec = "copy",
			filter = {"kind:WindowedApp or ConsoleApp", "dll-*"},
			from = "${QFRAMEWORK3}/libs/{system}-{arch}/qbase{suffix}{.dll}"
		}
	},
	depends = {
	    {
	        filter = {"windows"},
	        links = {"user32", "kernel32", "winmm"}
	    }
	}
});


library("qxml", {
	includedirs = {
		"${QFRAMEWORK3}/include"
	},
	libdirs = {"${QFRAMEWORK3}/libs/{system}-{arch}"},
	links = {"qxml{suffix}{.lib}"},
	postbuildcmds = {
		{
			exec = "copy",
			filter = {"kind:WindowedApp or ConsoleApp", "dll-*"},
			from = "${QFRAMEWORK3}/libs/{system}-{arch}/qxml{suffix}{.dll}"
		}
	},
	depends = {"qbase"}
});
]]--
