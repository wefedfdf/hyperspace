#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Hyperspace.sh"

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "================================================================"
        echo "退出脚本1，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1. 部署hypers节点14"
        echo "2. 查看日志"
        echo "3. 查看积分"
        echo "4. 删除节点（停止节点）"
        echo "5. 启用日志监控"
        echo "6. 管理私钥"
        echo "7. 退出脚本"
        echo "================================================================"
        read -p "请输入选择 (1/2/3/4/5/6/7): " choice

        case $choice in
            1)  deploy_hyperspace_node ;;
            2)  view_logs ;; 
            3)  view_points ;;
            4)  delete_node ;;
            5)  start_log_monitor ;;
            6)  manage_keys ;;
            7)  exit_script ;;
            *)  echo "无效选择，请重新输入！"; sleep 2 ;;
        esac
    done
}

# 管理私钥的函数
function manage_keys() {
    while true; do
        clear
        echo "私钥管理"
        echo "================="
        echo "1. 添加新私钥"
        echo "2. 查看所有私钥"
        echo "3. 返回主菜单"
        echo "================="
        read -p "请选择操作 (1/2/3): " key_choice

        case $key_choice in
            1)  add_new_key ;;
            2)  view_all_keys ;;
            3)  return ;;
            *)  echo "无效选择！"; sleep 2 ;;
        esac
    done
}

# 添加新私钥
function add_new_key() {
    echo "请输入私钥描述（用于标识不同的私钥）："
    read -p "描述: " key_description
    
    # 创建私钥目录（如果不存在）
    mkdir -p "$HOME/.hyperspace/keys"
    
    # 生成唯一的文件名
    key_file="$HOME/.hyperspace/keys/key_${key_description}_$(date +%s).pem"
    
    echo "请输入私钥内容（按 CTRL+D 结束）："
    cat > "$key_file"
    
    if [ $? -eq 0 ]; then
        echo "私钥已保存到: $key_file"
        
        # 尝试导入私钥
        if ! aios-cli hive import-keys "$key_file" 2>&1 | tee /tmp/import_error.log; then
            echo "错误：私钥导入失败 (Line 237)"
            echo "导入错误信息："
            cat /tmp/import_error.log
            rm -f /tmp/import_error.log
            rm "$key_file"
            read -n 1 -s -r -p "按任意键继续..."
            return 1
        fi

        # 验证私钥是否成功导入
        if ! aios-cli hive whoami 2>/dev/null | grep -q "Account"; then
            echo "错误：私钥导入后验证失败 (Line 247)"
            rm "$key_file"
            read -n 1 -s -r -p "按任意键继续..."
            return 1
        fi

        echo "私钥导入成功！"
    else
        echo "错误：保存私钥时发生错误 (Line 254)"
        rm "$key_file" 2>/dev/null
    fi
    
    read -n 1 -s -r -p "按任意键继续..."
}

# 查看所有私钥
function view_all_keys() {
    echo "当前已导入的所有私钥："
    echo "======================="
    aios-cli hive whoami
    echo "======================="
    read -n 1 -s -r -p "按任意键继续..."
}

# 部署hyperspace节点
function deploy_hyperspace_node() {
    # 询问要部署的节点数量
    read -p "请输入要部署的节点数量: " node_count
    
    # 验证输入是否为正整数
    if ! [[ "$node_count" =~ ^[1-9][0-9]*$ ]]; then
        echo "错误：请输入有效的正整数"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    fi

    # 为每个节点执行部署
    for ((i=1; i<=node_count; i++)); do
        echo "部署节点 $i..."
        if ! deploy_single_node "$i"; then
            echo "节点 $i 部署失败，是否继续部署其他节点？(y/n)"
            read -p "请选择: " continue_deploy
            if [[ ! "$continue_deploy" =~ ^[Yy]$ ]]; then
                break
            fi
        fi
    done

    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# 部署单个节点的函数
function deploy_single_node() {
    local node_num=$1
    local screen_name="hyper_${node_num}"
    local work_dir="/root/.aios_node${node_num}"  # 为每个节点创建独立的工作目录
    local port=$((50051 + node_num - 1))  # 为每个节点分配不同端口
    
    # 创建并设置工作目录
    mkdir -p "$work_dir"
    export AIOS_HOME="$work_dir"  # 设置 AIOS_HOME 环境变量
    
    # 执行安装命令
    echo "正在执行安装命令：curl https://download.hyper.space/api/install | bash"
    if ! curl -s https://download.hyper.space/api/install | bash; then
        echo "安装失败，请检查网络连接或重试"
        return 1
    fi

    # 等待安装完成并刷新环境变量
    sleep 5
    
    echo "=== 诊断信息 ==="
    echo "1. 检查 aios-cli 文件"
    ls -l /root/.aios/aios-cli || echo "文件不存在"
    
    echo "2. 检查文件权限"
    stat /root/.aios/aios-cli 2>/dev/null || echo "无法获取文件状态"
    
    echo "3. 当前 PATH 环境变量"
    echo "$PATH"
    
    echo "4. 尝试直接执行 aios-cli"
    /root/.aios/aios-cli --help || echo "直接执行失败"
    
    echo "5. 检查可执行权限"
    if [ ! -x "/root/.aios/aios-cli" ]; then
        echo "添加执行权限..."
        chmod +x /root/.aios/aios-cli
    fi

    # 更新 PATH
    export PATH="/root/.aios:$PATH"
    source /root/.bashrc

    echo "6. 验证 aios-cli 命令"
    which aios-cli || echo "找不到 aios-cli 命令"
    
    echo "7. 再次尝试执行"
    if ! aios-cli --help >/dev/null 2>&1; then
        echo "错误：aios-cli 命令仍然无法执行"
        echo "请尝试手动执行："
        echo "export PATH=/root/.aios:\$PATH"
        echo "source /root/.bashrc"
        return 1
    fi

    echo "=== 诊断完成 ==="
    echo "aios-cli 安装验证成功"
    sleep 2

    # 清理已存在的屏幕会话
    echo "检查并清理现有的 '$screen_name' 屏幕会话..."
    screen -ls | grep "$screen_name" &>/dev/null && {
        echo "找到现有的 '$screen_name' 屏幕会话，正在停止并删除..."
        screen -S "$screen_name" -X quit
        sleep 2
    }

    # 创建新的屏幕会话
    echo "创建一个名为 '$screen_name' 的屏幕会话..."
    screen -dmS "$screen_name"
    sleep 2

    # 创建私钥目录
    mkdir -p "$HOME/.hyperspace/keys"
    local key_file="$HOME/.hyperspace/keys/node${node_num}_$(date +%s).pem"

    # 获取私钥
    echo "请输入节点 $node_num 的私钥（按 CTRL+D 结束）："
    if ! cat > "$key_file"; then
        echo "错误：私钥保存失败"
        rm -f "$key_file"
        return 1
    fi

    # 确保私钥文件不为空
    if [ ! -s "$key_file" ]; then
        echo "错误：私钥文件为空"
        rm -f "$key_file"
        return 1
    fi

    # 导入私钥前先初始化
    echo "初始化节点..."
    echo "运行命令：AIOS_HOME=$work_dir aios-cli start"
    # 在后台运行 aios-cli start
    AIOS_HOME="$work_dir" aios-cli start > "$work_dir/aios-cli_init.log" 2>&1 &
    # 等待守护进程启动
    sleep 5

    # 检查守护进程是否正在运行
    if ! AIOS_HOME="$work_dir" aios-cli status | grep -q "running"; then
        echo "错误：守护进程启动失败"
        cat "$work_dir/aios-cli_init.log"
        return 1
    fi

    echo "守护进程已成功启动"

    # 导入私钥
    echo "正在导入私钥..."
    echo "运行命令：AIOS_HOME=$work_dir aios-cli hive import-keys $key_file"
    if ! AIOS_HOME="$work_dir" aios-cli hive import-keys "$key_file"; then
        echo "错误：私钥导入失败，尝试重新导入..."
        echo "当前私钥内容："
        cat "$key_file"
        
        sleep 3
        echo "重新尝试导入..."
        if ! AIOS_HOME="$work_dir" aios-cli hive import-keys "$key_file"; then
            echo "私钥导入再次失败"
            return 1
        fi
    fi

    # 登录到 Hive
    echo "登录到 Hive..."
    echo "运行命令：AIOS_HOME=$work_dir aios-cli hive login"

    # 尝试登录，最多重试10次
    max_retries=10
    retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        if AIOS_HOME="$work_dir" aios-cli hive login 2>&1; then
            echo "登录成功！"
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                echo "登录失败 (尝试 $retry_count/$max_retries)"
                echo "可能原因："
                echo "1. Hive 服务暂时不可用 (503 错误)"
                echo "2. 网络连接问题"
                echo "3. 服务器维护中"
                echo "等待 30 秒后重试..."
                sleep 30
                
                # 重启守护进程
                echo "重启守护进程..."
                AIOS_HOME="$work_dir" aios-cli kill
                sleep 2
                AIOS_HOME="$work_dir" aios-cli start
                sleep 5

                # 检查守护进程是否正在运行
                if ! AIOS_HOME="$work_dir" aios-cli status | grep -q "running"; then
                    echo "守护进程未正常运行，尝试重新启动..."
                    AIOS_HOME="$work_dir" aios-cli start
                    sleep 5
                fi
            else
                echo "错误：登录失败，已重试 $max_retries 次"
                echo "建议："
                echo "1. 检查 Hive 服务状态"
                echo "2. 等待几分钟后重试"
                echo "3. 检查网络连接"
                echo "是否继续重试？(y/n)"
                read -p "请选择: " continue_retry
                if [[ "$continue_retry" =~ ^[Yy]$ ]]; then
                    echo "重置重试次数..."
                    retry_count=0
                    continue
                fi
                return 1
            fi
        fi
    done

    # 验证登录状态
    if ! AIOS_HOME="$work_dir" aios-cli hive whoami 2>/dev/null | grep -q "Public"; then
        echo "错误：登录状态验证失败"
        return 1
    fi

    echo "登录验证成功！"

    # 选择等级
    echo "请为节点 $node_num 选择等级（1-5）："
    select tier in 1 2 3 4 5; do
        if [[ "$tier" =~ ^[1-5]$ ]]; then
            echo "运行命令：AIOS_HOME=$work_dir aios-cli hive select-tier $tier"
            # 尝试选择等级
            tier_output=$(AIOS_HOME="$work_dir" aios-cli hive select-tier "$tier" 2>&1)
            if echo "$tier_output" | grep -q "This tier is disabled"; then
                echo "错误：等级 $tier 当前不可用"
                echo "原因：该等级需要更多的显存"
                echo "建议：请选择较低的等级"
                echo "可用等级："
                # 从低到高尝试每个等级
                for t in 1 2 3 4 5; do
                    if AIOS_HOME="$work_dir" aios-cli hive select-tier "$t" 2>&1 | grep -q "Successfully"; then
                        echo "- 等级 $t (可用)"
                    else
                        echo "- 等级 $t (不可用)"
                    fi
                done
                continue
            elif ! echo "$tier_output" | grep -q "Successfully"; then
                echo "错误：等级选择失败"
                echo "错误信息："
                echo "$tier_output"
                return 1
            fi

            # 验证选择的等级
            local selected_tier=$(AIOS_HOME="$work_dir" aios-cli hive whoami 2>&1 | grep "tier" | awk '{print $2}')
            if [ -z "$selected_tier" ]; then
                echo "警告：无法获取当前等级信息"
                echo "是否继续？(y/n)"
                read -p "请选择: " continue_deploy
                if [[ ! "$continue_deploy" =~ ^[Yy]$ ]]; then
                    return 1
                fi
            elif [ "$selected_tier" != "$tier" ]; then
                echo "警告：选择的等级 ($tier) 与实际等级 ($selected_tier) 不匹配"
                echo "原因可能是："
                echo "1. 系统自动降级到可用等级"
                echo "2. 硬件资源不足"
                echo "3. 服务器限制"
                echo "是否继续使用当前等级？(y/n)"
                read -p "请选择: " continue_deploy
                if [[ ! "$continue_deploy" =~ ^[Yy]$ ]]; then
                    return 1
                fi
            fi
            break
        else
            echo "请选择有效的等级（1-5）"
        fi
    done

    # 连接到 Hive
    echo "连接到 Hive..."
    local connect_retries=0
    local max_connect_retries=5

    while [ $connect_retries -lt $max_connect_retries ]; do
        # 检查端口占用
        if netstat -tuln | grep -q ":$port "; then
            echo "警告：端口 $port 已被占用"
            port=$((port + 1))
            echo "尝试使用新端口: $port"
        fi

        # 确保模型已下载
        echo "检查模型..."
        local model="hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf"
        if ! AIOS_HOME="$work_dir" aios-cli models list 2>&1 | grep -q "$model"; then
            echo "添加必需的模型..."
            if ! AIOS_HOME="$work_dir" aios-cli models add "$model" 2>&1; then
                echo "错误：模型添加失败"
                return 1
            fi
        fi

        # 尝试连接
        if AIOS_HOME="$work_dir" aios-cli hive connect 2>&1; then
            echo "成功连接到 Hive！"
            break
        else
            connect_retries=$((connect_retries + 1))
            if [ $connect_retries -lt $max_connect_retries ]; then
                echo "连接失败 (尝试 $connect_retries/$max_connect_retries)"
                echo "诊断信息："
                echo "1. 检查守护进程状态..."
                AIOS_HOME="$work_dir" aios-cli status
                echo "2. 检查端口状态..."
                netstat -tuln | grep ":$port"
                echo "3. 检查模型状态..."
                AIOS_HOME="$work_dir" aios-cli models list
                
                echo "重启守护进程..."
                AIOS_HOME="$work_dir" aios-cli kill
                sleep 2
                AIOS_HOME="$work_dir" aios-cli start
                sleep 5
            else
                echo "错误：连接失败，已达到最大重试次数"
                echo "是否继续重试？(y/n)"
                read -p "请选择: " continue_retry
                if [[ "$continue_retry" =~ ^[Yy]$ ]]; then
                    connect_retries=0
                    continue
                fi
                return 1
            fi
        fi
        sleep 5
    done

    # 在屏幕会话中启动节点
    echo "启动节点 $node_num..."
    screen -S "$screen_name" -X stuff "AIOS_HOME=$work_dir aios-cli start --connect >> $work_dir/aios-cli.log 2>&1\n"

    echo "节点 $node_num 部署完成"
    sleep 2
    return 0
}

# 查看积分
function view_points() {
    echo "正在查看积分..."
    source /root/.bashrc
    aios-cli hive points
    sleep 5
}

# 删除节点（停止节点）
function delete_node() {
    echo "正在使用 'aios-cli kill' 停止节点..."

    # 执行 aios-cli kill 停止节点
    aios-cli kill
    sleep 2
    
    echo "'aios-cli kill' 执行完成，节点已停止。"

    # 提示用户按任意键返回主菜单
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 启用日志监控
function start_log_monitor() {
    echo "启动日志监控..."

    # 创建监控脚本文件
    cat > /root/monitor.sh << 'EOL'
#!/bin/bash

# 获取所有 hyper_ 开头的 screen 会话
get_node_screens() {
    screen -ls | grep 'hyper_' | cut -d. -f1 | awk '{print $1}'
}

LAST_RESTART=$(date +%s)
MIN_RESTART_INTERVAL=300

while true; do
    current_time=$(date +%s)
    
    # 遍历所有节点的 screen 会话
    for screen_name in $(get_node_screens); do
        node_num=$(echo "$screen_name" | cut -d'_' -f2)
        LOG_FILE="/root/aios-cli_node${node_num}.log"
        
        # 检测到以下几种情况，触发重启
        if (tail -n 4 "$LOG_FILE" 2>/dev/null | grep -q "Last pong received.*Sending reconnect signal" || \
            tail -n 4 "$LOG_FILE" 2>/dev/null | grep -q "Failed to authenticate" || \
            tail -n 4 "$LOG_FILE" 2>/dev/null | grep -q "Failed to connect to Hive" || \
            tail -n 4 "$LOG_FILE" 2>/dev/null | grep -q "Another instance is already running" || \
            tail -n 4 "$LOG_FILE" 2>/dev/null | grep -q "\"message\": \"Internal server error\"" || \
            tail -n 4 "$LOG_FILE" 2>/dev/null | grep -q "thread 'main' panicked at") && \
           [ $((current_time - LAST_RESTART)) -gt $MIN_RESTART_INTERVAL ]; then
            
            echo "$(date): 节点 $node_num 检测到错误，正在重启..." >> /root/monitor.log
            
            # 先发送 Ctrl+C
            screen -S "$screen_name" -X stuff $'\003'
            sleep 5
            
            # 执行 aios-cli kill
            screen -S "$screen_name" -X stuff "aios-cli kill\n"
            sleep 5
            
            echo "$(date): 清理节点 $node_num 的日志..." > "$LOG_FILE"
            
            # 重新启动服务
            screen -S "$screen_name" -X stuff "aios-cli start --connect >> $LOG_FILE 2>&1\n"
            
            LAST_RESTART=$current_time
            echo "$(date): 节点 $node_num 已重启" >> /root/monitor.log
        fi
    done
    sleep 30
done
EOL

    # 添加执行权限
    chmod +x /root/monitor.sh

    # 在后台启动监控脚本
    nohup /root/monitor.sh > /root/monitor.log 2>&1 &

    echo "日志监控已启动，后台运行中。"
    echo "可以通过查看 /root/monitor.log 来检查监控状态"
    sleep 2
}

# 查看日志
function view_logs() {
    echo "正在查看日志..."
    LOG_FILE="/root/aios-cli.log"   # 日志文件路径

    if [ -f "$LOG_FILE" ]; then
        echo "显示日志的最后 200 行:"
        tail -n 200 "$LOG_FILE"   # 显示最后 200 行日志
    else
        echo "日志文件不存在: $LOG_FILE"
    fi

    # 提示用户按任意键返回主菜单
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 退出脚本
function exit_script() {
    echo "退出脚本..."
    exit 0
}

# 调用主菜单函数
main_menu
