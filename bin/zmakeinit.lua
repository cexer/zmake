
local maincpp_content = [[
//premake.vpath=.


int main(int argc, char** argv)
{
	return 0;
}


]]


local prescript_content = [[
solution("{name}", function()
	project("{name}", function()
		category ("ConsoleApp");
		directory("src");
	end);
end);
]]



--newoption {
--    trigger = "projname",
--    value = "NAME",
--    description = "Create empty project directory and files"
--};

newoption {
    trigger = "projdir",
    value = "DIR",
    description = "Project directory"
};

function init_solution(name)
  local slndir = (_OPTIONS["projdir"] or path.getabsolute("")) .. "/" .. name;
  slndir = slndir:gsub("\\", "/");
      lfs.mkdir(slndir);
      lfs.mkdir(slndir .. "/bin");
      lfs.mkdir(slndir .. "/tmp");
      lfs.mkdir(slndir .. "/doc");
      lfs.mkdir(slndir .. "/src");

      local scriptpath = slndir .. "/zmake.lua";
      local scriptf = io.open(scriptpath, "w");
      local scripttext = prescript_content:gsub("{name}", name);
      scriptf:write(scripttext);
      scriptf:close();
end


function init_project(name)
  local projdir = (_OPTIONS["projdir"] or path.getabsolute("")) .. "/" .. name .. "/src";
  projdir = projdir:gsub("\\", "/");
  
    local mainpath = projdir .. "/main.cpp";
    local mainf = io.open(mainpath, "w");
    mainf:write(maincpp_content);
    mainf:close();
end


function init_action()
  local initproj = _ACTION;
  if initproj then
    init_solution(initproj);
    init_project(initproj);
    return true;
  end
end

newaction {
    trigger = _ACTION,
    description = "Create empty project directory and files",
    execute = function()
		init_action();
	end
};
