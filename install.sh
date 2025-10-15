#!/bin/sh

set -e

# 检查 curl 是否安装
if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is not installed. Please install curl first."
    exit 1
fi

echo "Downloading sshx..."

# 创建临时文件
temp_file=$(mktemp)
trap "rm -f '$temp_file'" EXIT INT TERM

# 使用 curl 下载文件到临时位置，添加安全参数
if ! curl -fsSL --max-redirs 3 --max-time 30 https://raw.githubusercontent.com/zboyco/sshx/main/sshx.sh -o "$temp_file"; then
    echo "Error: Failed to download sshx. Please check your internet connection."
    exit 1
fi

# 验证下载的文件是否为有效的 bash 脚本
if ! bash -n "$temp_file" 2>/dev/null; then
    echo "Error: Downloaded file is corrupted or invalid."
    exit 1
fi

# 备份已存在的文件
if [ -f /usr/local/bin/sshx ]; then
    backup_file="/usr/local/bin/sshx.backup-$(date +%Y%m%d-%H%M%S)"
    echo "Backing up existing sshx to: $backup_file"
    if ! sudo cp /usr/local/bin/sshx "$backup_file" 2>/dev/null; then
        echo "Warning: Failed to backup existing file."
    fi
fi

# 使用 sudo 复制文件到 /usr/local/bin 目录
echo "Installing sshx to /usr/local/bin..."
if ! sudo cp "$temp_file" /usr/local/bin/sshx; then
    echo "Error: Failed to install sshx. Please check your permissions."
    exit 1
fi

# 使用 sudo 设置文件权限为 755 (rwxr-xr-x)
if ! sudo chmod 755 /usr/local/bin/sshx; then
    echo "Error: Failed to set execute permission."
    exit 1
fi

# 检查是否安装成功
if [ -f /usr/local/bin/sshx ] && [ -x /usr/local/bin/sshx ]; then
    echo ""
    echo "✓ sshx installed successfully!"
    echo ""
    echo "Usage: sshx --help"
else
    echo "Error: Installation verification failed."
    exit 1
fi

