-- about setfenv
-- https://blog.csdn.net/jayson520/article/details/51498848/

-- Global variables
_LIBRARIES = _LIBRARIES or {}; -- predefined libraries
_LIBRARY = {
	includedirs = {},
	libdirs = {},
	links = {},
	postbuildcmds = {},
	prebuildcmds = {}
};
_LIBRARY_APIS = {
	includedirs = function(dirs) {
		table.insert(_LIBRARY.includedirs, dirs);
	end,
	libdirs = function(table) {
		table.insert(_LIBRARY.libdirs, dirs);
	end,
	links = function(table) {
		table.insert(_LIBRARY.links, dirs);
	end,
	postbuildcmds = function(table) {
		table.insert(_LIBRARY.postbuildcmds, dirs);
	end,
	prebuildcmds = function(table) {
		table.insert(_LIBRARY.prebuildcmds, dirs);
	end
};
local _GLOBAL_ENV = _ENV;
setmetatable(_LIBRARY_APIS, {__index = _GLOBAL_ENV});
	
function library(name, defineProcdure)
	_LIBRARY = {};
	_LIBRARIES[name] = _LIBRARY;
	_LIBRARY.name = name;
	local _ENV = _LIBRARY_APIS;
	defineProcdure();
end


--library("boost", {
--    includedirs = {
--        "F:/develop/library/boost_1_61_0"
--    },
--    libdirs = {
--		"F:/develop/library/boost_1_61_0/link"
--    }
--});

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
