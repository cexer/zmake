local p = premake

p.modules.export_compile_commands = {}
local m = p.modules.export_compile_commands

local workspace = p.workspace
local project = p.project

function m.getToolset(cfg)
  if cfg.toolset then
    return p.tools[cfg.toolset]
  end
  -- Default based on system
  if os.istarget('windows') then
    return p.tools.msc or p.tools.clang
  end
  return p.tools.gcc
end

function m.getIncludeDirs(cfg)
  local flags = {}
  local toolset = m.getToolset(cfg)
  local isMsvc = toolset == p.tools.msc or toolset == p.tools.clang
  
  for _, dir in ipairs(cfg.includedirs) do
    if isMsvc then
      table.insert(flags, '/I' .. p.quoted(dir))
    else
      table.insert(flags, '-I' .. p.quoted(dir))
    end
  end
  
  for _, dir in ipairs(cfg.sysincludedir or {}) do
    if isMsvc then
      table.insert(flags, '/external:I' .. p.quoted(dir))
    else
      table.insert(flags, '-isystem ' .. p.quoted(dir))
    end
  end
  return flags
end

function m.getCommonFlags(cfg)
  local toolset = m.getToolset(cfg)
  local isMsvc = toolset == p.tools.msc or toolset == p.tools.clang
  local flags = toolset.getcppflags(cfg)
  
  -- Handle defines
  if isMsvc then
    for _, define in ipairs(cfg.defines or {}) do
      table.insert(flags, '/D' .. define)
    end
  else
    flags = table.join(flags, toolset.getdefines(cfg.defines))
  end
  
  -- Handle undefines
  if isMsvc then
    for _, undef in ipairs(cfg.undefines or {}) do
      table.insert(flags, '/U' .. undef)
    end
  else
    flags = table.join(flags, toolset.getundefines(cfg.undefines))
  end
  
  -- Include dirs and other flags
  flags = table.join(flags, m.getIncludeDirs(cfg))
  flags = table.join(flags, toolset.getcflags(cfg))
  
  -- Build options (already in correct format for each toolset)
  return table.join(flags, cfg.buildoptions)
end

function m.getObjectPath(prj, cfg, node)
  local toolset = m.getToolset(cfg)
  local ext = (toolset == p.tools.msc or toolset == p.tools.clang) and '.obj' or '.o'
  return path.join(cfg.objdir, path.appendExtension(node.objname, ext))
end

function m.getDependenciesPath(prj, cfg, node)
  local toolset = m.getToolset(cfg)
  local ext = (toolset == p.tools.msc or toolset == p.tools.clang) and '.d.json' or '.d'
  return path.join(cfg.objdir, path.appendExtension(node.objname, ext))
end

function m.getFileFlags(prj, cfg, node)
  local toolset = m.getToolset(cfg)
  local isMsvc = toolset == p.tools.msc or toolset == p.tools.clang
  local flags = m.getCommonFlags(cfg)
  
  if isMsvc then
    return table.join(flags, {
      '/Fo' .. m.getObjectPath(prj, cfg, node),
      '/c', node.abspath
    })
  else
    return table.join(flags, {
      '-o', m.getObjectPath(prj, cfg, node),
      '-MF', m.getDependenciesPath(prj, cfg, node),
      '-c', node.abspath
    })
  end
end

function m.generateCompileCommand(prj, cfg, node)
  local toolset = m.getToolset(cfg)
  local compiler = 'clang-cl.exe' -- default
  if toolset == p.tools.msc then
    compiler = 'clang-cl.exe'
  elseif toolset == p.tools.gcc then
    compiler = 'gcc'
  end
  
  return {
    directory = prj.location,
    file = node.abspath,
    command = compiler .. ' ' .. table.concat(m.getFileFlags(prj, cfg, node), ' ')
  }
end

function m.includeFile(prj, node, depth)
  return path.iscppfile(node.abspath)
end

function m.getConfig(prj)
  if _OPTIONS['export-compile-commands-config'] then
    return project.getconfig(prj, _OPTIONS['export-compile-commands-config'],
      _OPTIONS['export-compile-commands-platform'])
  end
  for cfg in project.eachconfig(prj) do
    -- just use the first configuration which is usually "Debug"
    return cfg
  end
end

function m.getProjectCommands(prj, cfg)
  local tr = project.getsourcetree(prj)
  local cmds = {}
  p.tree.traverse(tr, {
    onleaf = function(node, depth)
      if not m.includeFile(prj, node, depth) then
        return
      end
      table.insert(cmds, m.generateCompileCommand(prj, cfg, node))
    end
  })
  return cmds
end

local function execute()
  for wks in p.global.eachWorkspace() do
    local cfgCmds = {}
    for prj in workspace.eachproject(wks) do
      for cfg in project.eachconfig(prj) do
        local cfgKey = string.format('%s', cfg.shortname)
        if not cfgCmds[cfgKey] then
          cfgCmds[cfgKey] = {}
        end
        cfgCmds[cfgKey] = table.join(cfgCmds[cfgKey], m.getProjectCommands(prj, cfg))
      end
    end
    for cfgKey,cmds in pairs(cfgCmds) do
      local outfile = string.format('compile_commands/%s.json', cfgKey)
      p.generate(wks, outfile, function(wks)
        p.w('[')
        for i = 1, #cmds do
          local item = cmds[i]
          local command = string.format([[
          {
            "directory": "%s",
            "file": "%s",
            "command": "%s"
          }]],
          item.directory,
          item.file,
          item.command:gsub('\\', '\\\\'):gsub('"', '\\"'))
          if i > 1 then
            p.w(',')
          end
          p.w(command)
        end
        p.w(']')
      end)
    end
  end
end

newaction {
  trigger = 'export-compile-commands',
  description = 'Export compiler commands in JSON Compilation Database Format',
  execute = execute
}

return m
