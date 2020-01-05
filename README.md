zmake
================================
premake based project file generator

介绍
----

基于 premake 封装的，用户自己业余开发的项目生成工具。


使用
----

- [准备](#setup)
- [创建项目目录结构](#init)
- [编辑 zmake.lua](#script)
- [生成项目文件](#make)
- [调试生成脚本](#debug)
- [更多资料](#more)

### <a name="setup"></a>准备

1. 将本仓库 clone 到磁盘上任意目录。
2. 将 bin 目录添加到`PATH`变量中。

### <a name="init"></a>创建项目目录结构

在目标目录调用命令
```
zmakeinit 项目名称
```

此命令会在当前目录生成目录结构：
```
目标目录/
    └─项目名称/
        ├─zmake.lua
        ├─bin/
        ├─doc/
        ├─src/
        │   ├─main.cpp
        └─tmp/
```

### <a name="script"></a>编辑 zmake.lua

示例脚本
```lua
solution("hellozmake", function()
	project("hellolib", function()
		category ("StaticLib");
		directory("src");
	end);
	project("helloexe", function()
		category ("ConsoleApp");
		directory("src");
		depends("hellolib")
		dependbuilds("hellolib")
	end);
end);

```

### <a name="make"></a>生成项目文件

项目目录（zmake.lua 所在目录）调用命令
```
zmake [参数] 项目类型
```

支持参数：

| 参数              | 说明                                         |
|-------------------|-----------------------------------------------|
| --os              | 目标操作系统，可选 windows、macosx、linux   |
| --cc              | 编译器，可选 gcc、clang                      |
| --verbose         | 生成过程中显示详细调试信息                  |


支持项目类型：

| 项目类型         | 说明                                          |
|-------------------|-----------------------------------------------|
| codelite          | CodeLite 项目文件                            |
| xcode4            | Apple Xcode 4 项目文件                       |
| gmake             | GNU makefile                                  |
| vs2008            | Visual Studio 2008 项目文件                  |
| vs2010            | Visual Studio 2010 项目文件                  |
| vs2013            | Visual Studio 2013 项目文件                  |
| vs2015            | Visual Studio 2015 项目文件                  |
| vs2017            | Visual Studio 2017 项目文件                  |


### <a name="debug"></a>调试脚本

支持使用 ZeroBrane Studio 进行 lua 脚本调试。

1. 打开 ZeroBrane Studio，选择菜单 Project -> Start Debug Server。
2. 打开脚本文件，设置好断点。
3. 在项目目录调用命令（和`zmake`命令一样）
```
zmaked [参数] 项目类型
```
此命令会激活 ZeroBrane Studio 进入调试模式。

### <a name="more"></a>更多资料

[Premake Repository](https://github.com/premake/premake-core)

[Premake Wiki](https://github.com/premake/premake-core/wiki)
