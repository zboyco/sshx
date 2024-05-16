#!/bin/sh

# 使用 curl 下载文件，并使用 sudo 保存到 /usr/local/bin 目录
sudo curl -o /usr/local/bin/sshx https://raw.githubusercontent.com/zboyco/sshx/main/sshx.sh

# 使用 sudo 设置文件可执行权限
sudo chmod +x /usr/local/bin/sshx

# 检查是否下载成功并设置了可执行权限
if [ -f /usr/local/bin/sshx ] && [ -x /usr/local/bin/sshx ]; then
    echo "sshx install success."
else
    echo "sshx download or set execute permission failed."
fi

