#!/bin/bash

# 版本号
VERSION="v0.1.0"

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

# 函数：检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 函数：转义密码中的特殊字符（用于expect命令）
escape_password() {
    local password="$1"
    # 转义单引号：将 ' 替换为 '"'"'
    printf '%s' "${password//\'/\'\"\'\"\'}"
}

# 函数：转义密码用于shell命令字符串
escape_password_for_shell() {
    local password="$1"
    # 转义反斜杠、美元符号、双引号、反引号
    password="${password//\\/\\\\}"
    password="${password//\$/\\$}"
    password="${password//\"/\\\"}"
    password="${password//\`/\\\`}"
    printf '%s' "$password"
}

# 函数：构建配置文件数组
build_configs_array() {
    local -n arr=$1
    for file in "$config_dir/$config_prefix"*; do
        if [ -f "$file" ] && [ -x "$file" ]; then
            arr+=("$file")
        fi
    done
}

# 函数：检查是否为退出命令
is_exit_command() {
    local choice="$1"
    [ "$choice" == "q" ] || [ "$choice" == "quit" ] || [ "$choice" == "exit" ]
}

# 函数：比较版本号
compare_versions() {
    local version1="$1"
    local version2="$2"
    
    # 移除 v 前缀
    version1="${version1#v}"
    version2="${version2#v}"
    
    # 使用 sort -V 比较版本号
    if [ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -n1)" = "$version1" ] && [ "$version1" != "$version2" ]; then
        echo "older"
    elif [ "$version1" = "$version2" ]; then
        echo "same"
    else
        echo "newer"
    fi
}

# 函数：检查最新版本
check_latest_version() {
    echo "Checking for updates..."
    
    # 从 GitHub 获取最新版本的 sshx.sh
    local latest_version
    latest_version=$(curl -s https://raw.githubusercontent.com/zboyco/sshx/master/sshx.sh | grep '^VERSION=' | head -1 | cut -d'"' -f2)
    
    if [ -z "$latest_version" ]; then
        echo "Error: Failed to check for updates. Please check your internet connection."
        return 1
    fi
    
    echo "$latest_version"
}

# 函数：升级 sshx
upgrade_sshx() {
    echo "sshx upgrade utility"
    echo ""
    
    # 检查最新版本
    local latest_version
    latest_version=$(check_latest_version)
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    echo "Current version: $VERSION"
    echo "Latest version:  $latest_version"
    echo ""
    
    # 比较版本
    local comparison
    comparison=$(compare_versions "$VERSION" "$latest_version")
    
    if [ "$comparison" = "same" ]; then
        echo "✓ You are already running the latest version."
        return 0
    elif [ "$comparison" = "newer" ]; then
        echo "✓ You are running a newer version than the latest release."
        return 0
    fi
    
    echo "A new version is available!"
    echo ""
    read -p "Do you want to upgrade to $latest_version? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Upgrade cancelled."
        return 0
    fi
    
    echo ""
    echo "Downloading latest version..."
    
    # 查找 sshx 的安装位置
    local sshx_path
    sshx_path=$(which sshx 2>/dev/null)
    
    if [ -z "$sshx_path" ]; then
        # 如果 which 找不到，尝试常见位置
        if [ -f "/usr/local/bin/sshx" ]; then
            sshx_path="/usr/local/bin/sshx"
        elif [ -f "$HOME/.local/bin/sshx" ]; then
            sshx_path="$HOME/.local/bin/sshx"
        else
            echo "Error: Could not determine sshx installation location."
            echo "Please reinstall manually."
            return 1
        fi
    fi
    
    echo "Installation location: $sshx_path"
    
    # 下载新版本到临时文件
    local temp_file="/tmp/sshx-upgrade-$$"
    if ! curl -sL https://raw.githubusercontent.com/zboyco/sshx/master/sshx.sh -o "$temp_file"; then
        echo "Error: Failed to download the latest version."
        rm -f "$temp_file"
        return 1
    fi
    
    # 验证下载的文件
    if ! bash -n "$temp_file" 2>/dev/null; then
        echo "Error: Downloaded file is corrupted or invalid."
        rm -f "$temp_file"
        return 1
    fi
    
    # 备份当前版本
    local backup_file="${sshx_path}.backup"
    if ! cp "$sshx_path" "$backup_file" 2>/dev/null; then
        # 可能需要 sudo
        if ! sudo cp "$sshx_path" "$backup_file"; then
            echo "Error: Failed to backup current version."
            rm -f "$temp_file"
            return 1
        fi
    fi
    
    echo "Current version backed up to: $backup_file"
    
    # 替换文件
    if ! cp "$temp_file" "$sshx_path" 2>/dev/null; then
        # 可能需要 sudo
        if ! sudo cp "$temp_file" "$sshx_path"; then
            echo "Error: Failed to install new version."
            echo "Restoring backup..."
            sudo cp "$backup_file" "$sshx_path" 2>/dev/null || cp "$backup_file" "$sshx_path"
            rm -f "$temp_file"
            return 1
        fi
    fi
    
    # 设置执行权限
    if ! chmod +x "$sshx_path" 2>/dev/null; then
        sudo chmod +x "$sshx_path"
    fi
    
    # 清理
    rm -f "$temp_file"
    
    echo ""
    echo "✓ Successfully upgraded to version $latest_version"
    echo ""
    echo "You can restore the previous version using:"
    echo "  cp $backup_file $sshx_path"
}

# 函数：写入剪贴板复制命令到配置文件
write_clipboard_command() {
    local config_file="$1"
    local escaped_password="$2"
    
    if command_exists pbcopy; then
        echo "printf \"%s\" \"$escaped_password\" | pbcopy" >> "$config_file"
    elif command_exists xclip; then
        echo "printf \"%s\" \"$escaped_password\" | xclip -selection clipboard" >> "$config_file"
    elif command_exists xsel; then
        echo "printf \"%s\" \"$escaped_password\" | xsel --clipboard --input" >> "$config_file"
    else
        return 1
    fi
    echo "echo '--- password copied to clipboard ---'" >> "$config_file"
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
    echo "Password (optional, NOT RECOMMENDED for security reasons):"
    read -rs password
    echo ""
    if [ -z "$password" ]; then
        # echo "私钥文件路径（可选）："
        echo "Path to private key file (optional):"
        read -r private_key
        # 验证私钥文件
        if [ -n "$private_key" ]; then
            if [ ! -f "$private_key" ]; then
                echo "Error: Private key file '$private_key' does not exist."
                return 1
            fi
            if [ ! -r "$private_key" ]; then
                echo "Error: Private key file '$private_key' is not readable."
                return 1
            fi
        fi
    else
        # 检查expect命令
        if ! command_exists expect; then
            echo "Warning: 'expect' command is not installed. Password-based authentication will not work."
            echo "Please install expect: sudo apt-get install expect (Debian/Ubuntu) or brew install expect (macOS)"
            read -p "Continue anyway? (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                return 1
            fi
        fi
        echo "WARNING: Password will be stored in plain text in $config_dir"
        echo "It is HIGHLY RECOMMENDED to use SSH key-based authentication instead."
        read -p "Do you want to continue with password? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            return 1
        fi
        
        # 询问是否复制密码到剪贴板
        echo ""
        echo "Do you want to copy password to clipboard when connecting? (y/N):"
        read -p "> " copy_password_confirm
        if [[ "$copy_password_confirm" =~ ^[Yy]$ ]]; then
            copy_password_to_clipboard="yes"
        else
            copy_password_to_clipboard="no"
        fi
    fi
    
    # 询问是否使用 trzsz
    echo ""
    echo "Do you want to use trzsz for file transfer support? (y/N):"
    read -p "> " use_trzsz_confirm
    if [[ "$use_trzsz_confirm" =~ ^[Yy]$ ]]; then
        # 检查 trzsz 命令是否存在
        if ! command_exists trzsz; then
            echo "Warning: 'trzsz' command is not installed. File transfer support will not work."
            echo "Please install trzsz: https://github.com/trzsz/trzsz"
            read -p "Continue anyway? (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                return 1
            fi
        fi
        use_trzsz="yes"
    else
        use_trzsz="no"
    fi

    # 生成保存配置的文件路径
    config_file="$config_dir/$config_prefix$config_name"

    # 写入配置信息到文件
    echo "# desc $config_desc" > "$config_file"
    
    # 设置 trzsz 前缀
    local trzsz_prefix=""
    if [ "$use_trzsz" == "yes" ]; then
        trzsz_prefix="trzsz "
    fi
    
    if [ -n "$password" ]; then
        # 转义密码（用于expect命令）
        local escaped_password
        escaped_password=$(escape_password "$password")
        
        # 转义密码（用于shell命令）
        local escaped_password_shell
        escaped_password_shell=$(escape_password_for_shell "$password")
        
        # 根据用户选择决定是否复制密码到剪贴板
        if [ "$copy_password_to_clipboard" == "yes" ]; then
            write_clipboard_command "$config_file" "$escaped_password_shell"
        fi
        
        echo "expect -c 'spawn ${trzsz_prefix}ssh $username@$host -p $port -o ServerAliveInterval=60; expect \"password:\"; send \"'$escaped_password'\\r\"; interact'" >> "$config_file"
    else
        if [ -n "$private_key" ]; then
            echo "${trzsz_prefix}ssh -i \"$private_key\" $username@$host -p $port -o ServerAliveInterval=60" >> "$config_file"
        else
            echo "${trzsz_prefix}ssh $username@$host -p $port -o ServerAliveInterval=60" >> "$config_file"
        fi
    fi

    # 给文件添加可执行权限
    chmod +x "$config_file"

    # echo "已保存新的 SSH 配置：$config_name"
    echo "New ssh remote config saved: $config_file"
}

# 函数：列出所有 SSH 配置
list_ssh_configs() {
    # 检查是否存在配置文件
    local has_configs=0
    for config_file in "$config_dir/$config_prefix"*; do
        if [ -f "$config_file" ] && [ -x "$config_file" ]; then
            has_configs=1
            break
        fi
    done
    
    if [ $has_configs -eq 0 ]; then
        echo "No ssh remote config found."
        exit 1
    fi

    local count=1
    # 打印所有配置名称和描述，并添加序号
    echo "------------------------------------------------------------------"
    printf "  %-*s |  %-*s |  %s\n" 4 No. 20 Name Description
    echo "-------+-----------------------+----------------------------------"
    for config_file in "$config_dir/$config_prefix"*; do
        if [ -f "$config_file" ] && [ -x "$config_file" ]; then
            config_name=$(basename "$config_file")
            printf "  %-*s |  %-*s |  %s\n" 4 $count 20 ${config_name#$config_prefix} "$(sed -n '1 s/# desc //p' "$config_file")"
            ((count++))
        fi
    done
    echo "------------------------------------------------------------------"
    echo ""
}

# 函数：删除 SSH 配置
delete_ssh_config() {
    list_ssh_configs
    echo "Select a remote to delete (input number or name, press Ctrl+C to exit):"
    read -r choice
    # 如果用户输入 q 或 quit 或 exit，则退出程序
    if is_exit_command "$choice"; then
        exit 0
    fi
    
    local config_file=""
    local config_name=""
    
    # 判断用户输入是否是数字
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        # 如果是数字，根据序号找到对应配置
        local configs=()
        build_configs_array configs
        # 检查序号是否在有效范围内
        if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#configs[@]}" ]; then
            echo "Error: Invalid selection. Please choose a number between 1 and ${#configs[@]}."
            exit 1
        fi
        # 获取对应的配置文件（数组索引从0开始）
        config_file="${configs[$((choice-1))]}"
        config_name=$(basename "$config_file")
        config_name="${config_name#$config_prefix}"
    else
        # 否则，根据名称找到对应配置
        config_name="$choice"
        config_file="$config_dir/$config_prefix$choice"
    fi
    
    # 检查配置文件是否存在
    if [ ! -f "$config_file" ]; then
        echo "Error: Remote config '$config_name' not found."
        exit 1
    fi
    
    # 确认删除
    echo ""
    echo "Are you sure you want to delete remote '$config_name'? (y/N):"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Deletion cancelled."
        exit 0
    fi
    
    # 删除配置文件
    rm -f "$config_file"
    if [ $? -eq 0 ]; then
        echo "Remote config '$config_name' has been deleted."
    else
        echo "Error: Failed to delete remote config '$config_name'."
        exit 1
    fi
}

# 函数：选择并执行 SSH 配置
select_and_execute() {
    list_ssh_configs
    # echo "请选择（输入序号或名称, 按 Ctrl+C 退出）："
    echo "Select a remote (input number or name, press Ctrl+C to exit):"
    read -r choice
    # 如果用户输入 q 或 quit 或 exit，则退出程序
    if is_exit_command "$choice"; then
        exit 0
    fi
    # 判断用户输入是否是数字
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        # 如果是数字，根据序号执行对应配置
        # 构建配置文件数组
        local configs=()
        build_configs_array configs
        # 检查序号是否在有效范围内
        if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#configs[@]}" ]; then
            echo "Error: Invalid selection. Please choose a number between 1 and ${#configs[@]}."
            exit 1
        fi
        # 获取对应的配置文件（数组索引从0开始）
        config_file="${configs[$((choice-1))]}"
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

# 显示版本信息
show_version() {
    echo "sshx $VERSION"
}

# 帮助信息
usage() {
    echo "sshx $VERSION"
    echo ""
    echo "Usage: sshx [command]"
    echo "With no command, sshx will display a list of all saved connections."
    echo ""
    echo "Available commands:"
    echo "  new              Add a new SSH configuration"
    echo "  delete, rm       Delete an existing SSH configuration"
    echo "  upgrade          Upgrade sshx to the latest version"
    echo "  --help, -h       Display this help message"
    echo "  --version, -v    Display version information"
}

# 主函数
main() {
    if [ "$1" == "new" ]; then
        add_ssh_config
    elif [ "$1" == "delete" ] || [ "$1" == "rm" ]; then
        delete_ssh_config
    elif [ "$1" == "upgrade" ]; then
        upgrade_sshx
    elif [ "$1" == "-v" ] || [ "$1" == "--version" ]; then
        show_version
    elif [ "$1" == "help" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        usage
    else
        select_and_execute
    fi
}

# 执行主函数
main "$@"