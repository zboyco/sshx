#!/bin/bash

# 版本号
VERSION="v0.1.1"

# 设置保存配置的目录
config_dir="$HOME/.ssh/remote"
# 设置配置前缀
config_prefix="ssh-"

# 创建保存配置的目录（如果不存在）- 设置严格权限
mkdir -p "$config_dir"
chmod 700 "$config_dir"

# ==================== 通用工具函数 ====================

# 函数：检查 bash 版本
check_bash_version() {
    local min_version="3.2"
    local current_version="${BASH_VERSION%%[^0-9.]*}"

    # 若解析失败，fallback 到原始值
    if [ -z "$current_version" ]; then
        current_version="$BASH_VERSION"
    fi

    local comparison
    comparison=$(compare_versions "$current_version" "$min_version")

    if [ "$comparison" = "older" ]; then
        echo "Warning: This script requires bash version $min_version or higher."
        echo "Current version: $BASH_VERSION"
        return 1
    fi
    return 0
}

# 函数：统一的错误处理
handle_error() {
    local message="$1"
    local exit_code="${2:-1}"
    echo "Error: $message" >&2
    exit "$exit_code"
}

# 函数：统一的输入读取和验证
read_validated_input() {
    local prompt="$1"
    local validation_func="$2"
    local error_msg="$3"
    local default_value="$4"
    local is_password="${5:-false}"
    local input

    printf '%s\n' "$prompt" >&2
    if [ "$is_password" = "true" ]; then
        read -rs input
        printf '\n' >&2
    else
        read -r input
    fi

    # 使用默认值
    input="${input:-$default_value}"

    # 验证输入
    while [ -n "$validation_func" ] && ! $validation_func "$input"; do
        printf '%s\n' "$error_msg" >&2
        if [ "$is_password" = "true" ]; then
            read -rs input
            printf '\n' >&2
        else
            read -r input
        fi
        input="${input:-$default_value}"
    done

    echo "$input"
}

# 函数：验证配置名称是否合法
validate_config_name() {
    local name="$1"

    # 检查是否为空
    if [ -z "$name" ]; then
        echo "Error: Remote name cannot be empty." >&2
        return 1
    fi

    # 检查长度限制（最多50个字符）
    if [ ${#name} -gt 50 ]; then
        echo "Error: Remote name is too long (max 50 characters)." >&2
        return 1
    fi

    # 只允许字母、数字、下划线和连字符
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Remote name can only contain letters, numbers, underscore and hyphen." >&2
        return 1
    fi

    # 检查是否包含路径分隔符或其他危险字符
    if [[ "$name" == *"/"* ]] || [[ "$name" == *".."* ]] || [[ "$name" == *"~"* ]]; then
        echo "Error: Remote name contains invalid characters." >&2
        return 1
    fi

    return 0
}

# 函数：验证端口号
validate_port() {
    local port="$1"

    # 使用默认端口
    if [ -z "$port" ]; then
        return 0
    fi

    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "Error: Port must be a number." >&2
        return 1
    fi

    # 确保数值比较
    if [ "$((port))" -lt 1 ] || [ "$((port))" -gt 65535 ]; then
        echo "Error: Port must be between 1 and 65535." >&2
        return 1
    fi

    return 0
}

# 函数：验证主机名或IP
validate_host() {
    local host="$1"

    if [ -z "$host" ]; then
        echo "Error: Hostname or IP address cannot be empty." >&2
        return 1
    fi

    # 禁止包含危险字符
    if [[ "$host" =~ [\;\$\`\|\&\<\>\(\)\{\}\[\]\'\"\\\] ]]; then
        echo "Error: Hostname contains invalid characters." >&2
        return 1
    fi

    # 基本的主机名或IP格式检查
    # 允许域名、IPv4、IPv6（简化版）
    if [[ ! "$host" =~ ^[a-zA-Z0-9.:-]+$ ]]; then
        echo "Error: Invalid hostname or IP address format." >&2
        return 1
    fi

    return 0
}

# 函数：验证用户名
validate_username() {
    local username="$1"

    if [ -z "$username" ]; then
        echo "Error: Username cannot be empty." >&2
        return 1
    fi

    # 禁止包含危险字符
    if [[ "$username" =~ [\;\$\`\|\&\<\>\(\)\{\}\[\]\'\"\\\] ]]; then
        echo "Error: Username contains invalid characters." >&2
        return 1
    fi

    # Unix 用户名规则
    if [[ ! "$username" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        echo "Error: Username can only contain letters, numbers, underscore, hyphen and dot." >&2
        return 1
    fi

    return 0
}

# 函数：验证密码不包含换行/回车
validate_password_characters() {
    local password="$1"

    if [[ "$password" == *$'\n'* ]] || [[ "$password" == *$'\r'* ]]; then
        echo "Error: Password cannot contain newline or carriage return characters." >&2
        return 1
    fi

    return 0
}

# 函数：检查配置文件是否有效（修复：检查可读性而非可执行性）
is_valid_config() {
    local file="$1"
    [ -f "$file" ] && [ -r "$file" ]
}

# 函数：统一的确认提示
confirm_action() {
    local prompt="$1"
    local default="${2:-N}"  # 默认为 N
    local response

    if [ "$default" = "Y" ]; then
        read -p "$prompt (Y/n): " response
        [[ -z "$response" || "$response" =~ ^[Yy]$ ]]
    else
        read -p "$prompt (y/N): " response
        [[ "$response" =~ ^[Yy]$ ]]
    fi
}

# 函数：检查配置名称是否重复
check_duplicate_name() {
    local new_name="$1"
    local config_file="$config_dir/$config_prefix$new_name"

    if [ -f "$config_file" ]; then
        echo "Remote name '$new_name' already exists, please choose another name:"
        return 1
    fi
    return 0
}

# 函数：检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 函数：转义 shell 参数
shell_escape() {
    local str="$1"
    # 使用 printf %q 进行安全的 shell 转义
    printf '%q' "$str"
}

# 函数：为单引号字符串转义（用于密码等敏感数据）
escape_for_single_quotes() {
    local str="$1"
    # 将单引号 ' 替换为 '\''（结束引号，添加转义的单引号，重新开始引号）
    echo "${str//\'/\'\\\'\'}"
}

# 函数：获取文件权限（修复：跨平台兼容性）
get_file_permissions() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS 使用 stat -f %Lp
        stat -f %Lp "$file" 2>/dev/null
    else
        # Linux 使用 stat -c %a
        stat -c %a "$file" 2>/dev/null
    fi
}

# 函数：统一的配置文件列表构建和缓存
get_config_list() {
    local -a configs=()
    local config_file

    for config_file in "$config_dir/$config_prefix"*; do
        if is_valid_config "$config_file"; then
            configs+=("$config_file")
        fi
    done

    printf '%s\n' "${configs[@]}"
}

# 函数：检查是否为退出命令
is_exit_command() {
    local choice="$1"
    [ "$choice" == "q" ] || [ "$choice" == "quit" ] || [ "$choice" == "exit" ]
}

# 函数：比较版本号（修复：支持更多版本格式）
compare_versions() {
    local version1="${1#v}"
    local version2="${2#v}"

    # 移除版本后缀（如 -beta, -rc1 等）
    version1="${version1%%-*}"
    version2="${version2%%-*}"

    local IFS=.
    local i ver1=($version1) ver2=($version2)

    # 填充空白部分
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done

    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            echo "newer"
            return
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            echo "older"
            return
        fi
    done
    echo "same"
}

# ==================== 核心功能函数 ====================

# 函数：检查最新版本
check_latest_version() {
    echo "Checking for updates..." >&2

    # 使用 HTTPS 并添加安全标志
    local latest_version
    latest_version=$(curl -sfL --max-redirs 3 --max-time 10 https://raw.githubusercontent.com/zboyco/sshx/main/sshx.sh | grep '^VERSION=' | head -1 | cut -d'"' -f2)

    if [ -z "$latest_version" ]; then
        echo "Error: Failed to check for updates. Please check your internet connection." >&2
        return 1
    fi

    echo "$latest_version"
}

# 函数：升级 sshx（修复：添加 trap 清理临时文件）
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

    if ! confirm_action "Do you want to upgrade to $latest_version?"; then
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
            handle_error "Could not determine sshx installation location. Please reinstall manually."
        fi
    fi

    echo "Installation location: $sshx_path"

    # 使用更安全的临时文件名
    local temp_file
    temp_file=$(mktemp)

    # 设置 trap 确保清理临时文件
    trap "rm -f '$temp_file'" EXIT INT TERM

    # 下载新版本到临时文件（添加安全标志）
    if ! curl -sfL --max-redirs 3 --max-time 30 https://raw.githubusercontent.com/zboyco/sshx/main/sshx.sh -o "$temp_file"; then
        handle_error "Failed to download the latest version."
    fi

    # 验证下载的文件
    if ! bash -n "$temp_file" 2>/dev/null; then
        handle_error "Downloaded file is corrupted or invalid."
    fi

    # 检查下载文件的版本
    local downloaded_version
    downloaded_version=$(grep '^VERSION=' "$temp_file" | head -1 | cut -d'"' -f2)
    if [ "$downloaded_version" != "$latest_version" ]; then
        handle_error "Version mismatch in downloaded file."
    fi

    # 备份当前版本
    local backup_file="${sshx_path}.backup-$(date +%Y%m%d-%H%M%S)"
    if ! cp "$sshx_path" "$backup_file" 2>/dev/null; then
        # 可能需要 sudo
        if ! sudo cp "$sshx_path" "$backup_file"; then
            handle_error "Failed to backup current version."
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
            handle_error "Installation failed, backup restored."
        fi
    fi

    # 设置文件权限为 755 (rwxr-xr-x)
    if ! chmod 755 "$sshx_path" 2>/dev/null; then
        sudo chmod 755 "$sshx_path"
    fi

    echo ""
    echo "✓ Successfully upgraded to version $latest_version"
    echo ""
    echo "You can restore the previous version using:"
    echo "  cp $backup_file $sshx_path"
}

# 函数：写入剪贴板复制命令到配置文件（修复：使用单引号包围密码）
write_clipboard_command() {
    local config_file="$1"
    local password="$2"

    # 使用单引号转义，避免 shell 解释密码内容
    local escaped_password=$(escape_for_single_quotes "$password")

    # 使用 printf 而不是 echo 以避免解释转义序列
    if command_exists pbcopy; then
        echo "printf -- %s '$escaped_password' | pbcopy" >> "$config_file"
    elif command_exists xclip; then
        echo "printf -- %s '$escaped_password' | xclip -selection clipboard" >> "$config_file"
    elif command_exists xsel; then
        echo "printf -- %s '$escaped_password' | xsel --clipboard --input" >> "$config_file"
    else
        return 1
    fi
    echo "echo '--- password copied to clipboard ---'" >> "$config_file"
    return 0
}

# 函数：添加新的 SSH 配置（优化版）
add_ssh_config() {
    local config_name config_desc host port username password private_key
    local use_trzsz copy_password_to_clipboard

    # 使用统一的输入验证函数
    config_name=$(read_validated_input "Name for the new remote:" "validate_config_name" "Please enter a valid remote name:")

    # 检查重复
    while ! check_duplicate_name "$config_name"; do
        config_name=$(read_validated_input "" "validate_config_name" "Please enter a valid remote name:")
    done

    echo "Description for the new remote (optional):"
    read -r config_desc

    # 描述可以为空

    host=$(read_validated_input "Hostname or IP address:" "validate_host" "Please enter a valid hostname or IP address:")

    port=$(read_validated_input "Port number (default is 22):" "validate_port" "Please enter a valid port number (1-65535):" "22")

    username=$(read_validated_input "Username:" "validate_username" "Please enter a valid username:")

    echo "Password (optional, NOT RECOMMENDED for security reasons):"
    while true; do
        read -rs password
        echo ""
        if [ -z "$password" ]; then
            break
        fi
        if validate_password_characters "$password"; then
            break
        fi
        echo "Password contains unsupported characters (newline/carriage return)."
        echo "Please re-enter password or press Enter to skip:"
    done

    if [ -z "$password" ]; then
        echo "Path to private key file (optional):"
        read -r private_key
        # 验证私钥文件
        if [ -n "$private_key" ]; then
            # 展开波浪号
            private_key="${private_key/#\~/$HOME}"
            # 使用 shell_escape 进行安全处理
            private_key=$(shell_escape "$private_key")

            # 验证文件存在性（需要先反转义）
            local unescaped_key="${private_key//\\/}"
            if [ ! -f "$unescaped_key" ]; then
                handle_error "Private key file '$unescaped_key' does not exist."
            fi
            if [ ! -r "$unescaped_key" ]; then
                handle_error "Private key file '$unescaped_key' is not readable."
            fi

            # 检查私钥文件权限
            local key_perms=$(get_file_permissions "$unescaped_key")
            if [ -n "$key_perms" ] && [ "$key_perms" != "600" ] && [ "$key_perms" != "400" ]; then
                echo "Warning: Private key file permissions are too open."
                echo "It is recommended to run: chmod 600 '$unescaped_key'"
            fi
        fi
    else
        # 检查expect命令
        if ! command_exists expect; then
            echo "Warning: 'expect' command is not installed. Password-based authentication will not work."
            echo "Please install expect: sudo apt-get install expect (Debian/Ubuntu) or brew install expect (macOS)"
            if ! confirm_action "Continue anyway?"; then
                return 1
            fi
        fi
        echo "WARNING: Password will be stored in plain text in $config_dir"
        echo "It is HIGHLY RECOMMENDED to use SSH key-based authentication instead."
        if ! confirm_action "Do you want to continue with password?"; then
            return 1
        fi

        # 询问是否复制密码到剪贴板
        echo ""
        if confirm_action "Do you want to copy password to clipboard when connecting?"; then
            copy_password_to_clipboard="yes"
        else
            copy_password_to_clipboard="no"
        fi
    fi

    # 询问是否使用 trzsz
    echo ""
    if confirm_action "Do you want to use trzsz for file transfer support?"; then
        # 检查 trzsz 命令是否存在
        if ! command_exists trzsz; then
            echo "Warning: 'trzsz' command is not installed. File transfer support will not work."
            echo "Please install trzsz: https://github.com/trzsz/trzsz"
            if ! confirm_action "Continue anyway?"; then
                return 1
            fi
        fi
        use_trzsz="yes"
    else
        use_trzsz="no"
    fi

    # 生成保存配置的文件路径
    local config_file="$config_dir/$config_prefix$config_name"

    # 写入配置信息到文件
    echo "#!/bin/bash" > "$config_file"
    # 修复：确保描述信息格式正确
    echo "# desc: $config_desc" >> "$config_file"

    # 设置 trzsz 前缀
    local trzsz_prefix=""
    if [ "$use_trzsz" == "yes" ]; then
        trzsz_prefix="trzsz "
    fi

    # 提前进行参数转义
    local safe_username=$(shell_escape "$username")
    local safe_host=$(shell_escape "$host")
    local safe_port=$(shell_escape "$port")

    if [ -n "$password" ]; then
        # 使用单引号转义密码，避免 shell 解释
        local escaped_password
        escaped_password=$(escape_for_single_quotes "$password")

        # 根据用户选择决定是否复制密码到剪贴板
        if [ "$copy_password_to_clipboard" == "yes" ]; then
            write_clipboard_command "$config_file" "$password"
        fi

        # 使用环境变量构建 expect 命令（可配置超时时间）
        local timeout="${SSH_EXPECT_TIMEOUT:-30}"
        echo "SSHX_PASSWORD='${escaped_password}' expect -c \"" >> "$config_file"
        echo "  set timeout $timeout" >> "$config_file"
        echo "  spawn ${trzsz_prefix}ssh ${safe_username}@${safe_host} -p ${safe_port} -o ServerAliveInterval=60" >> "$config_file"
        echo "  expect {" >> "$config_file"
        echo "    \\\"password:\\\" {" >> "$config_file"
        echo "      send -- \\\"\\\$env(SSHX_PASSWORD)\\\\r\\\"" >> "$config_file"
        echo "      interact" >> "$config_file"
        echo "    }" >> "$config_file"
        echo "    eof {" >> "$config_file"
        echo "      puts \\\"Connection failed\\\"" >> "$config_file"
        echo "      exit 1" >> "$config_file"
        echo "    }" >> "$config_file"
        echo "    timeout {" >> "$config_file"
        echo "      puts \\\"Connection timeout\\\"" >> "$config_file"
        echo "      exit 1" >> "$config_file"
        echo "    }" >> "$config_file"
        echo "  }" >> "$config_file"
        echo "\"" >> "$config_file"
    else
        if [ -n "$private_key" ]; then
            echo "${trzsz_prefix}ssh -i ${private_key} ${safe_username}@${safe_host} -p ${safe_port} -o ServerAliveInterval=60" >> "$config_file"
        else
            echo "${trzsz_prefix}ssh ${safe_username}@${safe_host} -p ${safe_port} -o ServerAliveInterval=60" >> "$config_file"
        fi
    fi

    # 设置正确的文件权限：可读写和执行（700）
    chmod 700 "$config_file"

    echo "New ssh remote config saved: $config_file"
}

# 函数：从配置文件中安全地获取描述信息
get_config_description() {
    local config_file="$1"
    local description=""

    # 在前5行中查找描述行（支持有无 shebang 的情况）
    local desc_line=$(head -n 5 "$config_file" | grep '^# desc')

    if [ -n "$desc_line" ]; then
        # 尝试新格式 # desc: 描述内容
        if [[ "$desc_line" =~ ^#\ desc:\ (.+)$ ]]; then
            description="${BASH_REMATCH[1]}"
        # 尝试旧格式 # desc 描述内容
        elif [[ "$desc_line" =~ ^#\ desc\ (.+)$ ]]; then
            description="${BASH_REMATCH[1]}"
        fi
    fi

    # 返回描述（可能为空）
    echo "$description"
}

# 函数：列出所有 SSH 配置（优化版）
list_ssh_configs() {
    local configs
    configs=$(get_config_list)

    if [ -z "$configs" ]; then
        echo "No ssh remote config found."
        return 1
    fi

    local count=1
    local config_file config_name description

    # 打印所有配置名称和描述，并添加序号
    echo "------------------------------------------------------------------"
    printf "  %-*s |  %-*s |  %s\n" 4 No. 20 Name Description
    echo "-------+-----------------------+----------------------------------"

    while IFS= read -r config_file; do
        config_name=$(basename "$config_file")
        # 修复：使用新的函数获取描述信息
        description=$(get_config_description "$config_file")
        printf "  %-*s |  %-*s |  %s\n" 4 $count 20 "${config_name#$config_prefix}" "$description"
        ((count++))
    done <<< "$configs"

    echo "------------------------------------------------------------------"
    echo ""

    return 0
}

# 函数：通过选择获取配置文件
get_config_by_choice() {
    local choice="$1"
    local configs config_file

    configs=$(get_config_list)

    if [ -z "$configs" ]; then
        return 1
    fi

    # 判断用户输入是否是数字
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        # 如果是数字，根据序号找到对应配置
        local count=0
        local total=$(echo "$configs" | wc -l)

        # 检查序号是否在有效范围内
        if [ "$choice" -lt 1 ] || [ "$choice" -gt "$total" ]; then
            echo "Error: Invalid selection. Please choose a number between 1 and $total."
            return 1
        fi

        # 获取对应的配置文件
        config_file=$(echo "$configs" | sed -n "${choice}p")
    else
        # 验证配置名称
        if ! validate_config_name "$choice"; then
            return 1
        fi
        # 根据名称找到对应配置
        config_file="$config_dir/$config_prefix$choice"

        if [ ! -f "$config_file" ]; then
            echo "Error: Remote config '$choice' not found."
            return 1
        fi
    fi

    echo "$config_file"
}

# 函数：交互式选择配置（优化版）
select_config_interactive() {
    local prompt="$1"

    # 将列表输出到 stderr，避免被命令替换捕获
    if ! list_ssh_configs >&2; then
        return 1
    fi

    # 将提示输出到 stderr
    echo "$prompt" >&2
    read -r choice

    # 如果用户输入 q 或 quit 或 exit，则退出程序
    if is_exit_command "$choice"; then
        return 2
    fi

    local config_file
    config_file=$(get_config_by_choice "$choice" 2>&1)

    if [ $? -ne 0 ]; then
        return 1
    fi

    # 只将结果输出到 stdout
    echo "$config_file"
    return 0
}

# 函数：删除 SSH 配置（优化版）
delete_ssh_config() {
    local config_file
    config_file=$(select_config_interactive "Select a remote to delete (input number or name, press Ctrl+C to exit):")
    local exit_code=$?
    
    if [ $exit_code -eq 2 ]; then
        exit 0
    elif [ $exit_code -ne 0 ]; then
        exit 1
    fi

    local config_name=$(basename "$config_file")
    config_name="${config_name#$config_prefix}"

    # 确认删除
    echo ""
    if ! confirm_action "Are you sure you want to delete remote '$config_name'?"; then
        echo "Deletion cancelled."
        exit 0
    fi

    # 删除配置文件
    if rm -f "$config_file"; then
        echo "Remote config '$config_name' has been deleted."
    else
        handle_error "Failed to delete remote config '$config_name'."
    fi
}

# 函数：选择并执行 SSH 配置（优化版）
select_and_execute() {
    local config_file
    config_file=$(select_config_interactive "Select a remote (input number or name, press Ctrl+C to exit):")
    local exit_code=$?
    
    if [ $exit_code -eq 2 ]; then
        exit 0
    elif [ $exit_code -ne 0 ]; then
        exit 1
    fi

    if is_valid_config "$config_file"; then
        echo ""
        bash "$config_file"
    else
        handle_error "Remote config not found or not readable."
    fi
}

# ==================== 主程序 ====================

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
    echo ""
    echo "Environment variables:"
    echo "  SSH_EXPECT_TIMEOUT    Set expect timeout (default: 30 seconds)"
}

# 主函数
main() {
    # 检查 bash 版本（仅警告，不阻止执行）
    check_bash_version

    case "$1" in
        new)
            add_ssh_config
            ;;
        delete|rm)
            delete_ssh_config
            ;;
        upgrade)
            upgrade_sshx
            ;;
        -v|--version)
            show_version
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            select_and_execute
            ;;
    esac
}

# 执行主函数
main "$@"
