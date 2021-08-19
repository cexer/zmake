-- Options
newoption {
    trigger = "projdir",
    value = "DIR",
    description = "Project directory"
}

newoption {
    trigger = 'debuglog',
    value = false,
    description = "Print detail log"
}

newaction {
    trigger = 'version',
    description = "Print version",
    execute = function()
		print("1.0.0")
	end
}


-- Global variables
_SOLUTION = nil -- current solution
_PROJECT = nil  -- current project
_LIBRARIES = _LIBRARIES or {} -- predefined libraries
_LIBRARY = nil; -- current library

-- Project Categories
PROJECT_CATEGORY_LIBRARY = "Library" 	-- shared or static library
PROJECT_CATEGORY_SHARED = "SharedLib"	-- shared libary
PROJECT_CATEGORY_STATIC = "StaticLib"	-- static library
PROJECT_CATEGORY_CONSOLE = "ConsoleApp"  -- command line app
PROJECT_CATEGORY_WINDOW = "WindowedApp"    -- windowed gui app

-- backup original premake functions
local premakeAPI = {}
premakeAPI.pathappendextension = path.appendextension
premakeAPI.solution = solution
premakeAPI.project = project
premakeAPI.filename = filename
premakeAPI.targetname = targetname
premakeAPI.targetext = targetextension
premakeAPI.targetsuffix = targetsuffix
premakeAPI.targetprefix = targetprefix
premakeAPI.targetdir = targetdir
premakeAPI.objdir = objdir
premakeAPI.debugdir = debugdir
premakeAPI.defines = defines
premakeAPI.includedirs = includedirs
premakeAPI.libdirs = libdirs
premakeAPI.links = links
premakeAPI.runtime = runtime
premakeAPI.filter = filter

-- Default zmake.lua
if not _OPTIONS["file"] then
	_OPTIONS["file"] = "zmake.lua"
end

local enable_debug_log = _OPTIONS["debuglog"]
function DEBUG_LOG(fmt, ...)
	if (enable_debug_log) then
		local project_name = "_"
		if _PROJECT then
			project_name = _PROJECT.name
		end
		print(project_name .. " " .. fmt:format(...))
	end
end

premakeAPI.tabletostring = table.tostring
table.tostring = function(t, v, lf)
	local s = premakeAPI.tabletostring(t, v)
	if not lf then
		s = s:gsub("%\n", " ")
	end
	return s
end

-- Define library function
_LIBRARY_APIS = {
	includedirs = function(v)
		_LIBRARY.includedirs = table.join(_LIBRARY.includedirs, v)
	end,
	libdirs = function(v)
		_LIBRARY.libdirs = table.join(_LIBRARY.libdirs, v)
	end,
	links = function(v)
		_LIBRARY.links = table.join(_LIBRARY.links, v)
	end,
	postbuildcmds = function(v)
		_LIBRARY.postbuildcmds = table.join(_LIBRARY.postbuildcmds, v)
	end,
	postbuildcopydlls = function(v)
	    _LIBRARY_APIS.postbuildcmds {
	        {
	            exec = "copy",
	            filter = {"kind:WindowedApp or ConsoleApp", "dll-*"},
	            from = "{libdir}/{dllprefix}zui{-cc}{-sd}{.dll}"
	        }
	    }
	end,
	prebuildcmds = function(v)
		_LIBRARY.prebuildcmds = table.join(_LIBRARY.prebuildcmds, v)
	end,
	depends = function(v)
		if v.filter or v.links then
			v = {v}
		end
		_LIBRARY.depends = table.join(_LIBRARY.depends, v)
	end
}
setmetatable(_LIBRARY_APIS, {__index = _ENV})

-- https://leafo.net/guides/setfenv-in-lua52-and-above.html
-- https://stackoverflow.com/questions/14290527/recreating-setfenv-in-lua-5-2
if not setfenv then -- Lua 5.2
  -- based on http://lua-users.org/lists/lua-l/2010-06/msg00314.html
  -- this assumes f is a function
  --local function findenv(f)
  --  local level = 1
  --  repeat
  --    local name, value = debug.getupvalue(f, level)
  --    if name == '_ENV' then return level, value end
  --    level = level + 1
  --  until name == nil
  --  return nil end
  --getfenv = function (f) return(select(2, findenv(f)) or _G) end
  --setfenv = function (f, t)
  --  local level = findenv(f)
  --  if level then debug.setupvalue(f, level, t) end
  --  return f end
	setfenv = function(fn, env)
	  local i = 1
	  while true do
	    local name = debug.getupvalue(fn, i)
	    if name == "_ENV" then
	      debug.upvaluejoin(fn, i, (function()
	        return env
	      end), 1)
	      break
	    elseif not name then
	      break
	    end
	    i = i + 1
	  end
	  return fn
	end
end

function library(name, define_cb)
	_LIBRARY = {
		includedirs = {},
		libdirs = {},
		links = {},
		postbuildcmds = {},
		prebuildcmds = {},
		depends = {}
	}
	_LIBRARIES[name] = _LIBRARY
	_LIBRARY.name = name
	local _ENV = _LIBRARY_APIS
	setfenv(define_cb, _LIBRARY_APIS)()
end

-- hook path.appendextension to allow explicitly set extension (.lib/.a/.la) of a linked lib
path.appendextension = function(p, ext)
	-- if the extension is nil or empty, do nothing
	if not ext or ext == "" then
		return p
	end

	-- if the path ends with a quote, pull it off
	local endquote
	if p:endswith('"') then
		p = p:sub(1, -2)
		endquote = '"'
	end

	-- add the extension if it isn't there already
	if not p:endswith(".a") and not p:endswith(".lib") then
		p = p .. ext
	end
		
	-- put the quote back if necessary
	if endquote then
		p = p .. endquote
	end

	return p
end


-- hook os.commandTokens.windows.copy
-- the original windows copy command use xcopy command with /E /F /Y /I flags, which will copy all directory structures even it's empty, we don't want this.
os.commandTokens.windows.copy = function(v)
	return "xcopy /F /Y /I " .. path.translate(v)
end

function get_project_filename(base)
	if _ACTION:find("vs20") == 1 or os.target() == "windows" then
		return string.format("%s-%s", base, _ACTION)
	else
		return string.format("%s-%s-%s", base, os.target(), _ACTION)
	end
end


-- hook solution function
function solution(name, macroprefix_or_initialize_cb, initialize_cb)
	_SOLUTION = {}
	_SOLUTION.handle = premakeAPI.solution(name)

	if type(macroprefix_or_initialize_cb) == "function" then
		initialize_cb = macroprefix_or_initialize_cb
		_SOLUTION.macroprefix = string.upper(name)
	else
		_SOLUTION.macroprefix = macroprefix_or_initialize_cb
	end

	language("c++")
	location("")
	premakeAPI.objdir("tmpdir")

	-- symbols
	symbols("On")
	editAndContinue("Off")
	debugformat("Default")

	-- solution file name
	premakeAPI.filename(get_project_filename(name))

	-- configurations
	configurations {"dll-debug", "dll-release", "lib-debug", "lib-release"}

	-- platforms
	if (os.target() ~= "macosx") then
		platforms {"x32", "x64"}
	else
		platforms {"x64"}
	end

	-- -fdeclspec
	-- TODO: use 'clang' as condition
	if os.target() ~= "windows" then
		buildoptions { "-fdeclspec" }
	end

	-- -std=c++11
	if os.target() ~= "windows" then
		buildoptions { "-std=c++11" }
	end

	-- pthread
	if os.target() ~= "windows" then
		linkoptions { "-lpthread" }
	end

	-- vs2008 use c++98
	--if _ACTION ~= "vs2008" then
	--	if _ACTION:find("vs20") == 1 then
	--		cppdialect "c++11"
	--	else
	--		cppdialect "gnu++11"
	--	end
	--end

	-- platform/architecture
	if os.target() == "windows" then
		premakeAPI.defines {"_WIN32", "WIN32", "_ATL_XP_TARGETING", "UNICODE", "_UNICODE"}
		filter {"platforms:x64"} 
			premakeAPI.defines {"_WIN64", "WIN64"}
	end

	-- debug/release
	configuration {"*-debug"}  
		premakeAPI.defines {"_DEBUG"}
		premakeAPI.runtime("Debug")
		optimize("Off")
	configuration {"*-release"}  
		premakeAPI.defines {"NDEBUG"} 
		premakeAPI.runtime("Release")
		optimize("Speed")

	configuration {}

	-- apply user settings
	initialize_cb()

    -- end of current solution
	_SOLUTION = nil
end


-- hook project function
function project(name, macroprefix_or_initialize_cb, initialize_cb)
	_PROJECT = {}
	_PROJECT.name = name
	_PROJECT.handle = premakeAPI.project(name)
	DEBUG_LOG("start")

	_SOLUTION.projects = _SOLUTION.projects or {}
	_SOLUTION.projects[name]= _PROJECT

	if type(macroprefix_or_initialize_cb) == "function" then
		initialize_cb = macroprefix_or_initialize_cb
		_PROJECT.macroprefix = string.upper(name)
	else
		_PROJECT.macroprefix = macroprefix_or_initialize_cb
	end

	premakeAPI.defines(_PROJECT.macroprefix .. "_BUILD")

	-- apply user settings
	initialize_cb()

	if _PROJECT.category == nil then category() end			-- category
	if _PROJECT.runtime == nil then runtime() end 				-- runtime
	if _PROJECT.directory == nil then directory() end			-- directory\
	if _PROJECT.sourcedirs == nil then sourcedirs() end		-- sourcedirs
	if _PROJECT.filename == nil then filename() end			-- filename
	--if _PROJECT.targetext == nil then targetext() end		-- targetext
	--if _PROJECT.targetprefix == nil then targetprefix() end	-- targetprefix
	if _PROJECT.targetsuffix == nil then targetsuffix() end	-- targetsuffix
	if _PROJECT.targetname == nil then targetname() end		-- targetname
	if _PROJECT.targetdir == nil then targetdir() end			-- targetdir
	if _PROJECT.debugdir == nil then debugdir() end			-- debugdir
	if _PROJECT.postbuildcmds == nil then postbuildcmds() end			-- debugdir
	--if _PROJECT.includedirs == nil then includedirs() end	-- includedirs

	-- if this project is a predefined library, then add depends from it's predefined dependences.
	local predefined = _LIBRARIES[name]
	if predefined then
		local deps = predefined.depends
		if deps then
			depends(deps)
		end
	end

	DEBUG_LOG("done")
end

function runtime(rt)
	_PROJECT.macroprefix = _PROJECT.macroprefix or "PRE"
	_PROJECT.runtime = rt or "AutoRuntime"

	if _PROJECT.category == PROJECT_CATEGORY_SHARED then
		configuration {"*"} 
			premakeAPI.defines { _PROJECT.macroprefix .. "_SHARED" } 
			--flags { rt or "StaticRuntime" }
			staticruntime "Off"
	elseif _PROJECT.category == PROJECT_CATEGORY_STATIC then
		configuration {"*"} 
			premakeAPI.defines { _PROJECT.macroprefix .. "_STATIC"} 
			--flags { rt or "StaticRuntime" }
			staticruntime "On"
	else
		configuration {"dll-*"} 
			premakeAPI.defines { _PROJECT.macroprefix .. "_SHARED"} 
			--flags { rt or "StaticRuntime" }
			staticruntime "Off"
		configuration {"lib-*"} 
			premakeAPI.defines { _PROJECT.macroprefix .. "_STATIC"} 
			--flags { rt or "StaticRuntime" }
			staticruntime "On"
		configuration{}
	end
end

-- replace linux style envirement variables names to current toolset specific.
local function resolve_envs(var)
	local b, e = var:find("${(.-)}")
	if b ~= nil and e ~= nil then
		local prefix = var:sub(1, b - 1)
		local env = var:sub(b + 2, e - 1)
		local suffix = var:sub(e + 1)
	    if _ACTION:find("vs20")==1 or _ACTION == "codeblocks" then
	        return prefix .. "$(" .. env .. ")" .. suffix
	    else    
	        return prefix .. "${" .. env .. "}" .. suffix
	    end
	else
		return var
	end
end

function get_compiler_name()
	local cc = _OPTIONS["cc"]
	if cc then
		return cc
	elseif _ACTION:find("vs20") == 1 then
		return _ACTION
	else
		return "gcc"
	end
end

function get_compiler_name_or_empty()
	local cc = get_compiler_name()
	if cc == 'vs2008' then
		return ''
	else
		return "-" .. cc
	end
end

function get_lib_extension()
	if os.target() == "windows" then
		return ".lib"
	else
		return ".a"
	end
end

function get_lib_prefix()
	if os.target() == "windows" then
		return ""
	else
		return "lib"
	end
end

function get_dll_extension()
	if os.target() == "windows" then
		return ".dll"
	elseif os.target() == "macosx" then
		return ".dylib"
	else
		return ".so"
	end
end

function get_dll_prefix()
	if os.target() == "windows" then
		return ""
	else
		return "lib"
	end
end

-- replace tokens to valid premake style tokens
local function resolve_tokens(strings, isimp, rt)
	function resolve_one(v)
		local originv = v
		v = v:gsub("{slndir}", "%%{wks.location}")
		v = v:gsub("{bindir}", "%%{wks.location}/bin/")
		v = v:gsub("{libdir}", "%%{wks.location}/lib/{os}-{arch}")
		--v = v:gsub("%-", "-")
		v = v:gsub("{%-d}", "%%{iif(cfg.buildtarget.suffix:find('d'), 'd', '')}")
		-- forced to use shared library 
		if isimp and rt == PROJECT_CATEGORY_SHARED then
			v = v:gsub("{%-s}", "")
			v = v:gsub("{%-sd}", "%%{iif(cfg.buildtarget.suffix:find('d'), '-d', '')}")			
		-- forced to use static library
		elseif isimp and rt == PROJECT_CATEGORY_STATIC then
			v = v:gsub("{%-s}", "s")
			v = v:gsub("{%-sd}", "%%{iif(cfg.buildtarget.suffix:find('d'), '-sd', '-s')}")
		-- not forced, juge by target suffix, see if it has any of specific flags
		else
			v = v:gsub("{%-s}", "%%{iif(cfg.buildtarget.suffix:find('s'), 's', '')}")
			v = v:gsub("{%-sd}", "%%{cfg.buildtarget.suffix}")
		end
		v = v:gsub("{libprefix}", get_lib_prefix())
		v = v:gsub("{.lib}", get_lib_extension())
		v = v:gsub("{dllprefix}", get_dll_prefix)
		v = v:gsub("{.dll}", get_dll_extension)
		v = v:gsub("{arch}", "%%{cfg.architecture}")
		v = v:gsub("{os}", "%%{cfg.system}")
		v = v:gsub("{cc}", get_compiler_name())
		v = v:gsub("{%-cc}", get_compiler_name_or_empty())
		--v = v:gsub("{%-cc}", "%%{iif(cfg.buildtarget and cfg.buildtarget.suffix:find('s'), get_compiler_name(), '')}")
		v = v:gsub("{outdir}", "%%{cfg.buildtarget.directory}")
		v = v:gsub("{outpath}", "%%{cfg.buildtarget.relpath}")
		v = resolve_envs(v)
		--print("    resolved: " .. originv .. " -> " .. v)
		return v
	end

	if type(strings) == "string" then
		return resolve_one(strings)
	end

	for i, v in ipairs(strings) do
		strings[i] = resolve_one(v)
	end
	return strings
end


--local lfs = assert(package.loadlib("lfs.dll", "luaopen_lfs"))()
local lfs = require("lfs")

-- set project category
function category(name)
	_PROJECT.category = iif(name == nil, PROJECT_CATEGORY_CONSOLE, name)
    if _PROJECT.category == PROJECT_CATEGORY_LIBRARY then
        configuration {"lib-*"} kind "StaticLib"
        configuration {"dll-*"} kind "SharedLib"
	elseif _PROJECT.category == PROJECT_CATEGORY_SHARED then
		kind "SharedLib"
		--configmap {
		--	["lib-debug"] = "dll-debug",
		--	["lib-release"] = "dll-release"
		--}
	elseif _PROJECT.category == PROJECT_CATEGORY_STATIC then
		kind "StaticLib"
		--configmap {
		--	["dll-debug"] = "lib-debug",
		--	["dll-release"] = "lib-release" 
		--}
    elseif _PROJECT.category == PROJECT_CATEGORY_WINDOW then
        kind "WindowedApp"
        configuration {"windows"} flags { "WinMain" }
	else-- _PROJECT.category == PROJECT_CATEGORY_CONSOLE then
		kind "ConsoleApp"
    end
    
    configuration {}
end


-- set project file output location
function directory(dir)
	dir = dir or "builder"
	dir = resolve_tokens(dir)

	_PROJECT.directory = dir
	
	location(dir)
	configuration {}
end


-- set source directories and recursively add all source files and apply their vpaths.
function sourcedirs(dirs, opts)
    local recurrence = true
    local autovpath = true
    local novpath = false
    if type(opts) == "table" then
	    if type(opts.recurrence) ~= "nil" then
	    	recurrence = opts.recurrence
    	end
    	if type(opts.autovpath) ~= "nil" then
	    	autovpath = opts.autovpath
    	end
    	if type(opts.novpath) ~= "nil" then
	    	novpath = opts.novpath
    	end
    end

	dirs = dirs or {
        _PROJECT.directory,
		"include/" .. _PROJECT.name,
		"src/" .. _PROJECT.name,
	}
  if type(dirs) == "string" then
    dirs = {dirs}
  end

	_PROJECT.sourcedirs = dirs

	local function issourcefile(path, exts)
		local function extof(fullname)
			local ext = fullname:match(".*(%..-)$")
			return ext or ""
		end

		exts = exts or { ".c", ".cpp", ".cxx", ".cc", ".h", ".hh", ".hpp", ".hxx", ".m", ".mm" }
		local ext = extof(path):lower()
		for _, e in ipairs(exts) do
			if ext == e then
				return true
			end
		end
		return false
	end

	local function getsourcefiles(dir, exts, result)
		if dir:sub(-1) ~= "/" then
			dir = dir .. "/"
		end

		result = result or {}
	    for name in lfs.dir(dir) do
	        if name ~= "." and name ~= ".." then
	            local path = iif(dir == "./", name, dir .. name)
	            local attr = lfs.attributes(path)
	            if attr.mode == "directory" and recurrence then
	                getsourcefiles(path, exts, result)
	            elseif issourcefile(path, exts) then
	                table.insert(result, path)
	            end
	        end
	    end
		return result
	end

	local function getsourcedirss(dir, result)
		if dir:sub(-1) ~= "/" then
			dir = dir .. "/"
		end

		result = result or {}
	    for name in lfs.dir(dir) do
	        if name ~= "." and name ~= ".." then
	            local path = iif(dir == "./", name, dir .. name)
	            local attr = lfs.attributes(path)
	            if attr.mode == "directory" then
	                table.insert(result, path)
	                getsourcedirss(path, result)
	            end
	        end
	    end
		return result
	end

	local function getfilevpath(filepath)
		local abspath = path.getabsolute(filepath)
		local file = io.open(abspath, "rb")
	    local vpath = ""
		if file ~= nil then
			local linecount = 0
			for line in file:lines() do
				local _, _, vpath = line:find("//premake.vpath%s*=%s*([%a%p]+)")
				if vpath ~= nil then
	                file:close()
					return vpath
				end
				linecount = linecount + 1
				if linecount > 10 then
					file:close()
					return nil
				end
			end
			file:close()
		end
		return nil
	end

	local function getfiledir(path, exts)
		local _, i = path:find(".+/")
		if i == nil or i == 0 then
			i = path:find(".+\\")
		end
		if i ~= nil and i ~= 0 then
			return path:sub(1, i-1)
		elseif issourcefile(path, exts) then
			return "/"
		end
	end
	
    --local cd = lfs.currentdir()
    --local newcd = path.getabsolute(_PROJECT.directory)
	--assert(lfs.chdir(newcd))

	local fs = {}
	local ps = {}
    for _,dir in ipairs(dirs) do
    	local srcs = {}
    	getsourcefiles(dir, exts, srcs)
    	for _,path in ipairs(srcs) do
	    	if not novpath then
	    		local vpath = nil
	    		if autovpath then
		    		vpath = getfilevpath(path)
	    		end
	    		vpath = vpath or getfiledir(path, exts)
	    		if vpath ~= nil then
		          if vpath ~= "/" then
		            ps[vpath] = ps[vpath] or {}
		              table.insert(ps[vpath], path)
	          	  end
          		end
      		end
          	table.insert(fs, path)
    	end
    end

    if next(fs) then
    	files(fs)
    end

    if (not novpath) and next(ps) then
    	vpaths(ps)
	end

	--assert(lfs.chdir(cd))
	configuration {}
end


-- set project output filename
function filename(name)
	if name then
		name = resolve_tokens(name)
	else
		name = get_project_filename(_PROJECT.name)
    end

	_PROJECT.filename = name

    premakeAPI.filename(name)
	configuration {}
end


-- set build target file name
function targetname(name)
	if not name then
		name = _PROJECT.name .. "{-cc}"
	end

	local fullname = resolve_tokens(name)
	premakeAPI.targetname(fullname)

    _PROJECT.targetname = fullname

    configuration {}
end

-- set build target file prefix
--function targetprefix(prefix)
--	if not prefix then
--		if _PROJECT.category == PROJECT_CATEGORY_STATIC then
--			prefix = "{cc}-"
--		end
--	end

--	if prefix then
--		prefix = resolve_tokens(prefix)

--	    _PROJECT.targetprefix = prefix
--		premakeAPI.targetprefix(prefix)
		
--	    configuration {}
--	end
--end


-- set build target file extension
function targetext(ext)
	if ext then
		ext = resolve_tokens(ext)
		premakeAPI.targetext(ext)
	end

	_PROJECT.targetext = ext

    configuration {}
end


-- set build target file name suffix
function targetsuffix(suffix)
	if suffix then 
		premakeAPI.targetsuffix(suffix) 
    else
    	configuration {"dll-debug"} premakeAPI.targetsuffix(resolve_tokens("-d"))
    	configuration {"dll-release"} premakeAPI.targetsuffix("")
    	configuration {"lib-debug"} premakeAPI.targetsuffix "-sd"
    	configuration {"lib-release"} premakeAPI.targetsuffix "-s"
	end

	_PROJECT.targetsuffix = suffix or true

	configuration {}
end


-- set build target directory
function targetdir(dir)
	if dir then
		dir = resolve_tokens(dir)
	elseif _PROJECT.category == PROJECT_CATEGORY_CONSOLE or _PROJECT.category == PROJECT_CATEGORY_WINDOW then
		dir = "{bindir}"
	else
		dir = "{libdir}"
	end

	dir = resolve_tokens(dir)

	_PROJECT.targetdir = dir

    premakeAPI.targetdir(dir)
	configuration {}
end


-- set build intermidate directory
function tempdir(dir)
	if dir then
		dir = resolve_tokens(dir)
    else
        dir = "tmp"
    end

	_PROJECT.objdir = dir

	premakeAPI.objdir(dir)
	configuration {}
end


-- set debugging directory
function debugdir()
	if not dir then
    	dir = "{outdir}"
	end

	dir = resolve_tokens(dir)
	_PROJECT.debugdir = dir
	
	premakeAPI.debugdir(dir)
	configuration {}
end


-- add pre-build commands
function prebuildcmds(cmds)
	if cmds then
		resolve_tokens(cmds)
		prebuildcommands(cmds)
		configuration {}
	end
end


-- add post-build commands
function postbuildcmds(cmds)
	if not cmds then
		if _PROJECT.category == PROJECT_CATEGORY_SHARED and _ACTION ~= "xcode4" then
			cmds = {"{COPY} {outpath} {bindir}"}
		end
	end

	if cmds then
		cmds = table.deepcopy(cmds)
		_PROJECT.postbuildcmds = table.deepcopy(cmds)
		cmds = resolve_tokens(cmds)
		postbuildcommands(cmds)
		configuration {}
	end
end


-- add predefined macros
function defines(defs)
	if defs then
		premakeAPI.defines(defs) 
		configuration {} 
	end
end

function filter(v)
	if not v then
		v = {}
	end
	DEBUG_LOG("filter %s", table.tostring(v))
	premakeAPI.filter(v or {})
end

-- add include directoires
function includedirs(dirs)
	dirs = dirs or {
		"include/" .. _PROJECT.name,
		"src/" .. _PROJECT.name
	}
	resolve_tokens(dirs, true, _PROJECT.runtime)
	if dirs then
		DEBUG_LOG("includedirs %s", table.tostring(dirs))
		premakeAPI.includedirs(dirs) 
	end

    configuration {}
end

-- add library directories
function libdirs(dirs)
	resolve_tokens(dirs, true, _PROJECT.runtime)
	if dirs then
		DEBUG_LOG("libdirs %s", table.tostring(dirs))
		premakeAPI.libdirs(dirs)
	end

    configuration {} 
end

-- add link files
function links(files)
	resolve_tokens(files, true, _PROJECT.runtime)
	if files then
		DEBUG_LOG("links %s", table.tostring(files))
		premakeAPI.links(files)
	end

    configuration {} 
end

-- set dependences project which will be built before current project
function dependbuilds(names)
	for _, name in pairs(names) do
		if _PROJECT.category ~= PROJECT_CATEGORY_STATIC and _SOLUTION.projects[name] then
			local filter = "*"
			if _PROJECT.category == PROJECT_CATEGORY_LIBRARY then
				filter = "dll-*"
			end
			configuration {filter} premakeAPI.links(name)
		end
	    configuration {}
	end
end

-- add dependences libraries or projects
function depends(deps)
	DEBUG_LOG("depends %s start", table.tostring(deps))
    function resolve_lib_self(name, lib, libs, filter)
	    DEBUG_LOG("add %s", table.tostring(name))
        table.insert(libs, {
            name = name,
            includedirs = table.deepcopy(lib.includedirs),
            libdirs = table.deepcopy(lib.libdirs),
            links = table.deepcopy(lib.links),
            postbuildcmds = table.deepcopy(lib.postbuildcmds),
            prebuildcmds = table.deepcopy(lib.prebuildcmds),
            filter = table.deepcopy(filter),
            defines = table.deepcopy(lib.defines)
        })
    end

    function resolve_lib_deps(name, deps, libs, filter)
        for _, dep in pairs(deps) do
            if type(dep) == "string" then -- dep is library name
                resolve_lib_or_name(dep, libs, filter)
            elseif dep.links then -- dep is table with filter and links
                for _, link in pairs(dep.links) do
                    resolve_lib_or_name(link, libs, dep.filter)
                end
            else -- dep is string array
                for _, link in pairs(dep) do
                    resolve_lib_or_name(link, libs, filter)
                end
            end
        end
    end

    function resolve_file_name(name, libs, filter)
        table.insert(libs, {
            name = name,
            links = {name},
            filter = table.deepcopy(filter)
        })
    end

    function resolve_lib_or_name(name, libs, filter)
        local lib = _LIBRARIES[name]
        if lib then -- name refers to a predefined library
            if lib.depends then
                resolve_lib_deps(name, lib.depends, libs, filter)
            end
            resolve_lib_self(name, lib, libs, filter)
        else -- name is a library file name
            resolve_file_name(name, libs, filter)
        end
    end
    
	function resolve_all(names, libs, filter)
      libs = libs or {}
      filter = filter or {}
      for _, name in pairs(names) do
          resolve_lib_or_name(name, libs, filter)
      end
      return libs
	end

	local depends_projects={}
	local libs
	if type(deps) == "string" then
	  libs = resolve_all({deps}, libs)
	  table.insert(depends_projects, deps)
	elseif deps.links then -- deps is table with links
	  libs = resolve_all(deps.links, libs, deps.filter)
	else
	  for _, dep in pairs(deps) do
	      if type(dep) == "string" then
	        libs = resolve_all({dep}, libs)
	        table.insert(depends_projects, dep)
	      elseif dep.links then
	        libs = resolve_all(dep.links, libs, dep.filter)
	      end
	  end
	end
	dependbuilds(depends_projects)

	for _,lib in pairs(libs) do
    	filter(lib.filter)
		if lib.includedirs then
			includedirs(lib.includedirs)
		end
		if lib.libdirs then
			libdirs(lib.libdirs)
		end
		if lib.defines then
			defines(lib.defines)
		end
    
	    if _PROJECT.category ~= PROJECT_CATEGORY_STATIC then
	      if _PROJECT.category == PROJECT_CATEGORY_LIBRARY then
	        local filterplusdll = table.deepcopy(lib.filter) or {}
	        table.insert(filterplusdll, "dll-*")
	        filter(filterplusdll)
	      end
	      if lib.links then
	        links(lib.links)
	      end
	      filter(lib.filter)
	    end

		--[[if lib.links and _PROJECT.category ~= PROJECT_CATEGORY_STATIC then
			local filters = "*"
			if _PROJECT.category == PROJECT_CATEGORY_LIBRARY then
				filters = "dll-*"
			end
			configuration {filters} links(lib.links)
			configuration {}
		end
    ]]--

		function resolve_one_cmd(cmd)
    		local exec = cmd.exec
    		if exec == "copy" then
    			local to = resolve_tokens(cmd.to or " {outdir}")
    			local from = resolve_tokens(cmd.from)
    			exec = "{COPY} ".. from .. " " .. to
    		end
    		local ret = table.deepcopy(cmd)
    		ret.fixed = exec
    		return ret
		end
		function resolve_all_cmds(cmds)
    		local execs = {}
    		for _, cmd in pairs(cmds) do
        		table.insert(execs, resolve_one_cmd(cmd))
    		end
    		return execs
		end

		if lib.postbuildcmds then
    		local cmds = resolve_all_cmds(lib.postbuildcmds)
    		for _, cmd in ipairs(cmds) do
    			if (cmd.filter) then filter(cmd.filter) end
            	postbuildcmds({cmd.fixed})
          		if (cmd.filter) then filter{lib.filter} end
    		end
		end
		if lib.prebuildcmds then
    		local cmds = resolve_all_cmds(lib.prebuildcmds)
    		for _, cmd in ipairs(cmds) do
	    		if (cmd.filter) then filter(cmd.filter) end
            	prebuildcmds({cmd.fixed})
          		if (cmd.filter) then filter{lib.filter} end
    		end
		end
		filter{}
	end
	DEBUG_LOG("depends %s done", table.tostring(deps))
end
