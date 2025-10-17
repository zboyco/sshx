#!/bin/sh

set -e

# 检测下载工具 (优先级: curl > wget)
if command -v curl >/dev/null 2>&1; then
    DOWNLOAD_TOOL="curl"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOAD_TOOL="wget"
else
    echo "Error: Neither curl nor wget is installed. Please install one of them first."
    exit 1
fi

echo "Using $DOWNLOAD_TOOL for downloading..."

# 提示用户输入工具名称
echo "Please enter the tool name (press Enter for default 'sshx'):"
read -r TOOL_NAME

# 如果用户没有输入，使用默认值
if [ -z "$TOOL_NAME" ]; then
    TOOL_NAME="sshx"
fi

# 验证工具名称是否合法（只允许字母、数字、连字符、下划线）
if ! echo "$TOOL_NAME" | grep -qE '^[a-zA-Z0-9_-]+$'; then
    echo "Error: Tool name can only contain letters, numbers, hyphens, and underscores."
    exit 1
fi

echo "Tool name set to: $TOOL_NAME"
echo ""

echo "Downloading $TOOL_NAME..."

# 创建临时文件
temp_file=$(mktemp)
trap "rm -f '$temp_file'" EXIT INT TERM

# 根据可用工具下载文件，添加安全参数
if [ "$DOWNLOAD_TOOL" = "curl" ]; then
    if ! curl -fsSL --max-redirs 3 --max-time 30 https://raw.githubusercontent.com/zboyco/sshx/main/sshx.sh -o "$temp_file"; then
        echo "Error: Failed to download sshx. Please check your internet connection."
        exit 1
    fi
else
    if ! wget -q --max-redirect=3 --timeout=30 https://raw.githubusercontent.com/zboyco/sshx/main/sshx.sh -O "$temp_file"; then
        echo "Error: Failed to download sshx. Please check your internet connection."
        exit 1
    fi
fi

# 验证下载的文件是否为有效的 bash 脚本
if ! bash -n "$temp_file" 2>/dev/null; then
    echo "Error: Downloaded file is corrupted or invalid."
    exit 1
fi

# 备份已存在的文件
if [ -f /usr/local/bin/$TOOL_NAME ]; then
    backup_file="/usr/local/bin/${TOOL_NAME}.backup-$(date +%Y%m%d-%H%M%S)"
    echo "Backing up existing $TOOL_NAME to: $backup_file"
    if ! sudo cp /usr/local/bin/$TOOL_NAME "$backup_file" 2>/dev/null; then
        echo "Warning: Failed to backup existing file."
    fi
fi

# 使用 sudo 复制文件到 /usr/local/bin 目录
echo "Installing $TOOL_NAME to /usr/local/bin..."
if ! sudo cp "$temp_file" /usr/local/bin/$TOOL_NAME; then
    echo "Error: Failed to install $TOOL_NAME. Please check your permissions."
    exit 1
fi

# 使用 sudo 设置文件权限为 755 (rwxr-xr-x)
if ! sudo chmod 755 /usr/local/bin/$TOOL_NAME; then
    echo "Error: Failed to set execute permission."
    exit 1
fi

# 检查是否安装成功
if [ -f /usr/local/bin/$TOOL_NAME ] && [ -x /usr/local/bin/$TOOL_NAME ]; then
    echo ""
    echo "✓ $TOOL_NAME installed successfully!"
    echo ""
    echo "Usage: $TOOL_NAME --help"
else
    echo "Error: Installation verification failed."
    exit 1
fi

