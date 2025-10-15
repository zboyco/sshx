# sshx

[English](README.md) | 简体中文

sshx 是一个用于管理 SSH 连接的命令行工具。它提供了一个简单直观的界面，用于管理多个 SSH 连接并在其上执行命令。

<img alt="Welcome to sshx" src="https://raw.githubusercontent.com/zboyco/sshx/master/demo.gif" width="600" />

## 安装

### 自动安装（推荐）

> **注意：需要 sudo 权限才能将 sshx 安装到 /usr/local/bin。**

**通过 curl 安装：**
```bash
curl -s https://raw.githubusercontent.com/zboyco/sshx/master/install.sh | sh
```

**通过 wget 安装：**
```bash
wget https://raw.githubusercontent.com/zboyco/sshx/master/install.sh -O - | sh
```

### 手动安装

如果您不想使用自动安装脚本：

1. 下载脚本：
   ```bash
   curl -O https://raw.githubusercontent.com/zboyco/sshx/master/sshx.sh
   ```

2. 添加执行权限：
   ```bash
   chmod +x sshx.sh
   ```

3. 移动到 PATH 目录：
   ```bash
   # 方式1：系统级安装（需要 sudo）
   sudo mv sshx.sh /usr/local/bin/sshx
   
   # 方式2：用户级安装（不需要 sudo）
   mkdir -p ~/.local/bin
   mv sshx.sh ~/.local/bin/sshx
   export PATH="$HOME/.local/bin:$PATH"  # 添加到 ~/.bashrc 或 ~/.zshrc
   ```

4. 验证安装：
   ```bash
   sshx --help
   ```

## 使用方法

```
sshx v0.1.1

用法: sshx [命令]

不带命令时，sshx 将显示所有已保存的连接列表。

可用命令:
  new              添加新的 SSH 配置
  delete, rm       删除现有的 SSH 配置
  upgrade          升级 sshx 到最新版本
  --help, -h       显示帮助信息
  --version, -v    显示版本信息

环境变量:
  SSH_EXPECT_TIMEOUT    设置 expect 超时时间（默认：30 秒）
```

## 功能特性

- 🚀 **简易管理** - 简单的命令行界面管理 SSH 连接
- 🔐 **多种认证方式** - 支持密码和 SSH 密钥认证
- 📝 **配置描述** - 为连接添加描述信息，便于识别
- 🗑️ **轻松删除** - 删除不再需要的配置
- ⌨️ **多种选择方式** - 通过序号或名称选择连接
- 🔒 **安全警告** - 使用不安全认证方式时发出警告
- 📁 **trzsz 支持** - 可选的 trzsz 文件传输支持

## 重要提示

> ⚠️ **使用 sshx 之前：** 强烈建议在将服务器添加到 sshx 之前，先使用标准的 `ssh` 命令手动连接一次远程服务器。这样可以确保服务器的主机密钥指纹已保存到 `~/.ssh/known_hosts` 文件中。
>
> ```bash
> # 首次手动连接以接受主机密钥
> ssh user@your-server.com
> # 当提示主机真实性时输入 'yes'
> # 然后退出并将配置添加到 sshx
> ```
>
> 这可以防止因主机密钥验证提示导致的连接失败，特别是在使用密码认证配合 expect 时。

## 使用示例

### 添加新的 SSH 连接

```bash
$ sshx new
Name for the new remote:
> my-server
Description for the new remote (optional):
> 我的生产服务器
Hostname or IP address:
> 192.168.1.100
Port number (default is 22):
> 22
Username:
> admin
Password (optional, NOT RECOMMENDED for security reasons):
> [密码已隐藏]

WARNING: Password will be stored in plain text in /Users/username/.ssh/remote
It is HIGHLY RECOMMENDED to use SSH key-based authentication instead.
Do you want to continue with password? (y/N):
> n

Path to private key file (optional):
> ~/.ssh/id_rsa

Do you want to use trzsz for file transfer support? (y/N):
> n
New ssh remote config saved: /Users/username/.ssh/remote/ssh-my-server
```

### 列出并连接到已保存的连接

```bash
$ sshx
------------------------------------------------------------------
  No.  |  Name                  |  Description
-------+-----------------------+----------------------------------
  1    |  my-server             |  我的生产服务器
  2    |  dev-server            |  开发环境
------------------------------------------------------------------

Select a remote (input number or name, press Ctrl+C to exit):
> 1
# 连接到 my-server
```

### 删除连接

```bash
$ sshx delete
------------------------------------------------------------------
  No.  |  Name                  |  Description
-------+-----------------------+----------------------------------
  1    |  my-server             |  我的生产服务器
  2    |  dev-server            |  开发环境
------------------------------------------------------------------

Select a remote to delete (input number or name, press Ctrl+C to exit):
> 2

Are you sure you want to delete remote 'dev-server'? (y/N):
> y
Remote config 'dev-server' has been deleted.
```

或使用简写命令：

```bash
$ sshx rm
```

### 升级 sshx

```bash
$ sshx upgrade
sshx upgrade utility

Checking for updates...
Current version: v0.1.1
Latest version:  v0.2.0

A new version is available!

Do you want to upgrade to v0.2.0? (Y/n): y

Downloading latest version...
Installation location: /usr/local/bin/sshx
Current version backed up to: /usr/local/bin/sshx.backup

✓ Successfully upgraded to version v0.2.0

You can restore the previous version using:
  cp /usr/local/bin/sshx.backup /usr/local/bin/sshx
```

## 安全说明

- 🔐 **推荐使用 SSH 密钥认证** - 为了更好的安全性，请使用基于 SSH 密钥的认证而不是密码
- ⚠️ **⚠️ 重要：密码存储警告 ⚠️** - 如果选择使用密码认证：
  - **密码将以明文形式存储**在 `~/.ssh/remote/` 目录中
  - 任何能访问您用户账户的人都可以读取这些密码
  - 可以选择性启用连接时复制密码到剪贴板（出于安全考虑默认禁用）
  - 不建议在生产环境或敏感环境中使用
  - **请始终优先使用 SSH 密钥认证以确保安全**
- 🔒 **文件权限** - 配置文件创建时仅所有者具有可执行权限

## 系统要求

- **bash** - 脚本使用 bash 编写
- **expect** - 仅在使用密码认证时需要
- **ssh** - OpenSSH 客户端
- **trzsz**（可选）- 文件传输支持。安装地址：https://github.com/trzsz/trzsz

## 配置存储

所有 SSH 配置都存储在 `~/.ssh/remote/` 目录中，文件名前缀为 `ssh-`。每个配置都是一个独立的可执行脚本。

### 直接运行配置脚本

您可以不使用 `sshx` 直接执行配置脚本：

```bash
# 使用完整路径直接执行
~/.ssh/remote/ssh-my-server

# 或在 ~/.bashrc 或 ~/.zshrc 中添加目录到 PATH
export PATH="$HOME/.ssh/remote:$PATH"

# 然后可以直接通过名称运行
ssh-my-server
```

这允许您：
- 为常用服务器创建快捷方式
- 与其他工具和脚本集成
- 绕过 sshx 菜单快速访问

## trzsz 文件传输

如果在创建连接时启用了 trzsz 支持，您可以在 SSH 会话期间使用 `trz` 和 `tsz` 命令传输文件：

- **trz** - 从远程接收文件到本地（类似 `rz`）
- **tsz** - 从本地发送文件到远程（类似 `sz`）

**使用示例：**
```bash
# 在远程服务器上，下载文件到本地
tsz file.txt

# 在远程服务器上，从本地上传文件
trz
```

**安装方法：**
- macOS: `brew install trzsz-ssh`
- Linux: 从 https://github.com/trzsz/trzsz/releases 下载
- 更多信息：https://trzsz.github.io/cn/

## 安全改进

相比早期版本，当前版本包含以下安全改进：

- ✅ **密码特殊字符转义** - 正确处理密码中的特殊字符
- ✅ **隐藏密码输入** - 输入密码时不显示在屏幕上
- ✅ **安全警告提示** - 使用密码认证时显示安全警告
- ✅ **需要明确确认** - 使用密码认证前需要用户确认
- ✅ **依赖检查** - 使用密码认证前检查 expect 是否安装
- ✅ **跨平台剪贴板支持** - 支持 macOS (pbcopy)、Linux (xclip/xsel)
- ✅ **私钥文件验证** - 验证私钥文件是否存在和可读
- ✅ **输入边界检查** - 验证用户输入的有效性

## 常见问题与故障排除

### 如何使用 SSH 密钥认证？

在添加配置时，密码留空，然后输入私钥文件路径（通常是 `~/.ssh/id_rsa`）。

### expect 命令未找到 / 密码认证不工作

**问题：** 使用密码认证时出现 "expect: command not found"

**解决方案：** 安装 expect：
```bash
# macOS
brew install expect

# Ubuntu/Debian
sudo apt-get install expect

# CentOS/RHEL
sudo yum install expect
```

### 执行配置时权限被拒绝

**问题：** 配置文件存在但无法执行

**解决方案：** 确保配置文件有执行权限：
```bash
chmod +x ~/.ssh/remote/ssh-your-config-name
```

### 私钥文件未找到或不可读

**问题：** 使用 SSH 密钥认证时出错

**解决方案：**
1. 验证密钥文件是否存在：
   ```bash
   ls -l ~/.ssh/id_rsa
   ```

2. 检查文件权限（应为 600 或 400）：
   ```bash
   chmod 600 ~/.ssh/id_rsa
   ```

3. 添加配置时使用绝对路径：
   ```bash
   /home/username/.ssh/id_rsa
   # 或
   ~/.ssh/id_rsa
   ```

### trzsz 命令未找到

**问题：** 启用了 trzsz 但命令不可用

**解决方案：** 按照 [trzsz 文件传输](#trzsz-文件传输) 章节安装 trzsz，或重新创建配置时不启用 trzsz。

### 手动连接正常但通过 sshx 失败

**问题：** 使用 `ssh user@host` 可以连接，但通过 sshx 配置失败

**解决方案：**
1. 查看生成的配置文件：
   ```bash
   cat ~/.ssh/remote/ssh-your-config-name
   ```

2. 直接执行看错误信息：
   ```bash
   bash ~/.ssh/remote/ssh-your-config-name
   ```

3. 确认所有路径（SSH 密钥）使用绝对路径

### 配置未显示

**问题：** 添加了配置但列表中看不到

**解决方案：**
1. 检查配置目录：
   ```bash
   ls -la ~/.ssh/remote/
   ```

2. 确保文件有正确的前缀 `ssh-` 且可执行：
   ```bash
   chmod +x ~/.ssh/remote/ssh-*
   ```

## 卸载

完全删除 sshx：

1. 删除 sshx 命令：
   ```bash
   # 如果是系统级安装
   sudo rm /usr/local/bin/sshx
   
   # 如果是用户级安装
   rm ~/.local/bin/sshx
   ```

2. （可选）删除所有保存的配置：
   ```bash
   rm -rf ~/.ssh/remote/
   ```
   
   ⚠️ **警告：** 这将删除所有已保存的 SSH 配置。请确保在删除前备份。

3. （可选）如果手动添加了 PATH，从配置文件中删除：
   ```bash
   # 编辑 ~/.bashrc 或 ~/.zshrc 删除以下行：
   # export PATH="$HOME/.local/bin:$PATH"
   ```

## 许可证

MIT
