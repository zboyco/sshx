#!/bin/bash

# 设置保存配置的目录
config_dir="$HOME/.ssh/remote"
# 设置配置前缀
config_prefix="ssh-"

# 创建保存配置的目录（如果不存在）
mkdir -p "$config_dir"

# 函数：检查配置名称是否重复
check_duplicate_name() {
    local new_name="$1"
    for config_file in "$config_dir"/*; do
        if [ -x "$config_file" ]; then
            existing_name=$(basename "$config_file")
            if [ "$config_prefix$new_name" == "$existing_name" ]; then
                # echo "配置名称 '$new_name' 已存在，请选择其他名称:"
                echo "Remote name '$new_name' already exists, please choose another name:"
                return 1
            fi
        fi
    done
    return 0
}

# 函数：添加新的 SSH 配置
add_ssh_config() {
    # echo "新配置的名称："
    echo "Name for the new remote:"
    read -r config_name
    while [ -z "$config_name" ]; do
        # echo "配置名称不能为空，请重新输入："
        echo "Remote name cannot be empty, please try again:"
        read -r config_name
    done
    while ! check_duplicate_name "$config_name"; do
        read -r config_name
    done
    
    # echo "新配置的描述信息（可选）："
    echo "Description for the new remote (optional):"
    read -r config_desc
    # echo "主机名或 IP 地址："
    echo "Hostname or IP address:"
    read -r host
    while [ -z "$host" ]; do
        # echo "主机名或 IP 地址不能为空，请重新输入："
        echo "Hostname or IP address cannot be empty, please try again:"
        read -r host
    done
    # echo "端口号（默认为22）："
    echo "Port number (default is 22):"
    read -r port
    port=${port:-22} # 如果没有输入端口号，则默认为22
    # echo "用户名："
    echo "Username:"
    read -r username
    while [ -z "$username" ]; do
        # echo "用户名不能为空，请重新输入："
        echo "Username cannot be empty, please try again:"
        read -r username
    done
    # echo "密码（可选）："
    echo "Password (optional):"
    read -r password
    if [ -z "$password" ]; then
        # echo "私钥文件路径（可选）："
        echo "Path to private key file (optional):"
        read -r private_key
    fi

    # 生成保存配置的文件路径
    config_file="$config_dir/$config_prefix$config_name"

    # 写入配置信息到文件
    echo "# desc $config_desc" > "$config_file"
    if [ -n "$password" ]; then
        echo "printf '$password' | pbcopy" >> "$config_file"
        echo "echo '--- password copied to clipboard ---'" >> "$config_file"
        echo "expect -c 'spawn ssh $username@$host -p $port -o ServerAliveInterval=60; expect \"password:\"; send \"$password\\r\"; interact'" >> "$config_file"
    else
        if [ -n "$private_key" ]; then
            echo "ssh -i \"$private_key\" $username@$host -p $port -o ServerAliveInterval=60" >> "$config_file"
        else
            echo "ssh $username@$host -p $port -o ServerAliveInterval=60" >> "$config_file"
        fi
    fi

    # 给文件添加可执行权限
    chmod +x "$config_file"

    # echo "已保存新的 SSH 配置：$config_name"
    echo "New ssh remote config saved: $config_file"
}

# 函数：列出所有 SSH 配置
list_ssh_configs() {
    if [ -z "$(ls -A "$config_dir")" ]; then
        # echo "没有找到任何 SSH 配置。"
        echo "No ssh remote config found."
        exit 1
    fi

    local count=1
    # 打印所有配置名称和描述，并添加序号
    echo "------------------------------------------------------------------"
    printf "  %-*s |  %-*s |  %s\n" 4 No. 20 Name Description
    echo "-------+-----------------------+----------------------------------"
    for config_file in "$config_dir/$config_prefix"*; do
        if [ -x "$config_file" ]; then
            config_name=$(basename "$config_file")
            printf "  %-*s |  %-*s |  %s\n" 4 $count 20 ${config_name#$config_prefix} "$(sed -n '1 s/# desc //p' "$config_file")"
            ((count++))
        fi
    done
    echo "------------------------------------------------------------------"
    echo ""
}

# 函数：选择并执行 SSH 配置
select_and_execute() {
    list_ssh_configs
    # echo "请选择（输入序号或名称, 按 Ctrl+C 退出）："
    echo "Select a remote (input number or name, press Ctrl+C to exit):"
    read -r choice
    # 如果用户输入 q 或 quit 或 exit，则退出程序
    if [ "$choice" == "q" ] || [ "$choice" == "quit" ] || [ "$choice" == "exit" ]; then
        exit 0
    fi
    # 判断用户输入是否是数字
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        # 如果是数字，根据序号执行对应配置
        config_file="$config_dir/$(ls "$config_dir" | sed -n "${choice}p")"
    else
        # 否则，根据名称执行对应配置
        config_file="$config_dir/$config_prefix$choice"
    fi
    if [ -x "$config_file" ]; then
        echo ""
        bash "$config_file"
    else
        # echo "配置 '$choice' 不存在或不可执行。"
        echo "Remote config '$choice' not found or not executable."
        exit 1
    fi
}

# 帮助信息
usage() {
    echo "Usage: sshx [command]"
    echo "With no command, sshx will display a list of all saved connections."
    echo ""
    echo "Available commands:"
    echo "  new           Add a new SSH configuration"
    echo "  --help, -h    Display this help message"
}

# 主函数
main() {
    if [ "$1" == "new" ]; then
        add_ssh_config
    elif [ "$1" == "help" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        usage
    else
        select_and_execute
    fi
}

# 执行主函数
main "$@"