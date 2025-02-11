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
        echo "1. 部署hypers节点积分5"
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
            3)  check_score ;;
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

# 清理 PATH 环境变量的函数
function clean_path() {
    PATH=$(echo $PATH | tr ':' '\n' | awk '!seen[$0]++' | tr '\n' ':' | sed 's/:$//')
}

# 验证工作目录
function verify_workdir() {
    local work_dir=$1
    # 确保目录存在且有正确权限
    mkdir -p "$work_dir"
    chmod 755 "$work_dir"
    
    # 检查是否可写
    if ! touch "$work_dir/.test" 2>/dev/null; then
        echo "错误：工作目录无写入权限"
        return 1
    fi
    rm -f "$work_dir/.test"
    return 0
}

# 验证端口可用性
function verify_port() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        return 1
    fi
    return 0
}

# 改进的进程清理
function cleanup_processes() {
    local work_dir=$1
    echo "清理进程..."
    
    # 先尝试正常停止
    if AIOS_HOME="$work_dir" aios-cli kill 2>/dev/null; then
        sleep 2
    fi
    
    # 检查并强制结束残留进程
    local pids=$(pgrep -f "AIOS_HOME=$work_dir")
    if [ -n "$pids" ]; then
        echo "强制结束残留进程: $pids"
        kill -9 $pids 2>/dev/null
        sleep 2
    fi
    
    # 验证清理结果
    if pgrep -f "AIOS_HOME=$work_dir" > /dev/null; then
        echo "错误：无法清理所有进程"
        return 1
    fi
    return 0
}

# 验证节点状态的函数
function verify_node_status() {
    local work_dir=$1
    local timeout=$2
    local start_time=$(date +%s)

    while true; do
        # 检查是否超时
        local current_time=$(date +%s)
        if [ $((current_time - start_time)) -gt $timeout ]; then
            return 1
        fi

        # 检查守护进程
        if ! AIOS_HOME="$work_dir" aios-cli status 2>/dev/null | grep -q "running"; then
            sleep 2
            continue
        fi

        # 检查初始化日志
        if ! tail -n 50 "$work_dir/init.log" 2>/dev/null | grep -q "gRPC server listening"; then
            sleep 2
            continue
        fi

        # 验证成功
        return 0
    done
}

# 验证连接状态的函数
function verify_connection() {
    local work_dir=$1
    local timeout=$2
    local start_time=$(date +%s)

    while true; do
        # 检查是否超时
        local current_time=$(date +%s)
        if [ $((current_time - start_time)) -gt $timeout ]; then
            return 1
        fi

        # 检查连接状态
        if ! AIOS_HOME="$work_dir" aios-cli hive status 2>/dev/null | grep -q "connected"; then
            sleep 2
            continue
        fi

        # 检查心跳
        if ! tail -n 20 "$work_dir/init.log" 2>/dev/null | grep -q "Ping sent successfully"; then
            sleep 2
            continue
        fi

        # 验证成功
        return 0
    done
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
    local work_dir="/root/.aios_node${node_num}"
    local port=$((50051 + node_num - 1))
    
    echo "=== 开始部署节点 $node_num ==="
    
    # 验证工作目录
    if ! verify_workdir "$work_dir"; then
        return 1
    fi
    
    # 验证端口
    if ! verify_port "$port"; then
        echo "错误：端口 $port 已被占用"
        return 1
    }
    
    # 清理进程
    if ! cleanup_processes "$work_dir"; then
        return 1
    fi

    # 创建并验证私钥
    mkdir -p "$HOME/.hyperspace/keys"
    chmod 700 "$HOME/.hyperspace/keys"
    local key_file="$HOME/.hyperspace/keys/node${node_num}_$(date +%s).pem"
    
    echo "请输入节点 $node_num 的私钥（按 CTRL+D 结束）："
    if ! cat > "$key_file"; then
        echo "错误：私钥保存失败"
        rm -f "$key_file"
        return 1
    fi
    
    if [ ! -s "$key_file" ]; then
        echo "错误：私钥文件为空"
        rm -f "$key_file"
        return 1
    fi
    chmod 600 "$key_file"

    # 启动守护进程
    echo "启动守护进程..."
    AIOS_HOME="$work_dir" aios-cli start > "$work_dir/init.log" 2>&1 &
    
    # 等待初始化完成
    local init_timeout=30
    local init_start=$(date +%s)
    while true; do
        if [ $(($(date +%s) - init_start)) -gt $init_timeout ]; then
            echo "错误：初始化超时"
            cat "$work_dir/init.log"
            return 1
        fi
        
        if AIOS_HOME="$work_dir" aios-cli status 2>/dev/null | grep -q "running"; then
            if tail -n 50 "$work_dir/init.log" 2>/dev/null | grep -q "gRPC server listening"; then
                break
            fi
        fi
        sleep 2
    done
    echo "守护进程已初始化"

    # 导入私钥
    echo "导入私钥..."
    local import_result=$(AIOS_HOME="$work_dir" aios-cli hive import-keys "$key_file" 2>&1)
    if ! echo "$import_result" | grep -q "Successfully"; then
        echo "错误：私钥导入失败"
        echo "$import_result"
        return 1
    fi

    # 登录并验证
    echo "登录到 Hive..."
    local login_result=$(AIOS_HOME="$work_dir" aios-cli hive login 2>&1)
    if ! echo "$login_result" | grep -q "Authenticated successfully"; then
        echo "错误：登录失败"
        echo "$login_result"
        return 1
    fi

    # 连接并等待就绪
    echo "连接到 Hive..."
    AIOS_HOME="$work_dir" aios-cli hive connect > "$work_dir/connect.log" 2>&1 &
    
    # 等待连接就绪
    local connect_timeout=30
    local connect_start=$(date +%s)
    while true; do
        if [ $(($(date +%s) - connect_start)) -gt $connect_timeout ]; then
            echo "错误：连接超时"
            cat "$work_dir/connect.log"
            return 1
        fi
        
        if AIOS_HOME="$work_dir" aios-cli hive status 2>/dev/null | grep -q "connected"; then
            if tail -n 20 "$work_dir/init.log" 2>/dev/null | grep -q "Ping sent successfully"; then
                break
            fi
        fi
        sleep 2
    done
    echo "连接已就绪"

    # 选择等级
    local max_attempts=10
    local current_attempt=0
    local tier_selected=false
    
    while [ $current_attempt -lt $max_attempts ] && ! $tier_selected; do
        echo "请为节点 $node_num 选择等级（1-5）："
        select tier in 1 2 3 4 5; do
            if [[ "$tier" =~ ^[1-5]$ ]]; then
                local result=$(AIOS_HOME="$work_dir" aios-cli hive select-tier "$tier" 2>&1)
                if echo "$result" | grep -q "Successfully"; then
                    tier_selected=true
                    break 2
                else
                    echo "等级 $tier 暂时不可用："
                    echo "$result"
                    break
                fi
            fi
        done
        
        current_attempt=$((current_attempt + 1))
        if [ $current_attempt -eq $((max_attempts/2)) ]; then
            echo "尝试重新连接..."
            AIOS_HOME="$work_dir" aios-cli kill
            sleep 3
            AIOS_HOME="$work_dir" aios-cli start
            sleep 5
            AIOS_HOME="$work_dir" aios-cli hive login
            sleep 2
            AIOS_HOME="$work_dir" aios-cli hive connect
            sleep 5
        fi
    done

    if ! $tier_selected; then
        echo "错误：无法设置等级"
        return 1
    fi

    # 启动节点
    echo "启动节点 $node_num..."
    screen -dmS "$screen_name"
    screen -S "$screen_name" -X stuff "AIOS_HOME=$work_dir aios-cli start --connect >> $work_dir/aios-cli.log 2>&1\n"

    # 最终验证
    local final_check=0
    while [ $final_check -lt 6 ]; do
        if tail -n 20 "$work_dir/aios-cli.log" 2>/dev/null | grep -q "Ping sent successfully"; then
            echo "节点运行正常"
            echo "=== 节点 $node_num 部署完成 ==="
            return 0
        fi
        final_check=$((final_check + 1))
        sleep 5
    done

    echo "警告：节点已启动但未检测到心跳"
    return 1
}

# 查询积分的函数
function check_score() {
    clear  # 清屏以获得更好的显示效果
    echo "================================================================"
    echo "                        节点状态和积分查询                         "
    echo "================================================================"
    
    # 查找所有节点目录
    local node_dirs=(/root/.aios_node*)
    if [ ${#node_dirs[@]} -eq 0 ]; then
        echo "未找到任何节点"
        echo "按任意键返回主菜单..."
        read -n 1 -s
        return 1
    fi

    # 遍历每个节点
    for work_dir in "${node_dirs[@]}"; do
        local node_num=$(echo "$work_dir" | grep -o '[0-9]*$')
        echo
        echo "节点 $node_num 状态检查"
        echo "----------------------------------------------------------------"
        
        # 检查守护进程
        echo -n "守护进程状态: "
        if AIOS_HOME="$work_dir" aios-cli status 2>/dev/null | grep -q "running"; then
            echo "运行中"
        else
            echo "未运行"
            echo "尝试重启守护进程..."
            AIOS_HOME="$work_dir" aios-cli start > /dev/null 2>&1 &
            sleep 3
        fi

        # 检查登录状态和公钥
        local whoami_output=$(AIOS_HOME="$work_dir" aios-cli hive whoami 2>&1)
        echo -n "登录状态: "
        if echo "$whoami_output" | grep -q "Public"; then
            echo "已登录"
            echo "公钥: $(echo "$whoami_output" | grep "Public" | awk '{print $2}')"
        else
            echo "未登录"
            # 尝试重新登录
            echo "尝试重新登录..."
            AIOS_HOME="$work_dir" aios-cli hive login > /dev/null 2>&1
        fi
        
        # 检查连接状态
        echo -n "连接状态: "
        if AIOS_HOME="$work_dir" aios-cli hive status 2>&1 | grep -q "connected"; then
            echo "已连接"
        else
            echo "未连接"
            # 尝试重新连接
            echo "尝试重新连接..."
            AIOS_HOME="$work_dir" aios-cli hive connect > /dev/null 2>&1 &
            sleep 5  # 等待连接建立
        fi
        
        # 查询积分
        echo "积分信息:"
        local points_output=$(AIOS_HOME="$work_dir" aios-cli hive points 2>&1)
        if [[ "$points_output" != *"error"* ]]; then
            echo "$points_output" | sed 's/^/  /'  # 缩进显示
        else
            echo "  积分查询失败，请确保节点已连接"
        fi

        # 检查心跳
        if [ -f "$work_dir/aios-cli.log" ]; then
            echo "心跳状态:"
            if tail -n 20 "$work_dir/aios-cli.log" 2>/dev/null | grep -q "Ping sent successfully"; then
                echo "  ✓ 正常"
                echo "  最后心跳: $(tail -n 20 "$work_dir/aios-cli.log" | grep "Ping sent successfully" | tail -n 1 | cut -d']' -f1 | tr -d '[]')"
                echo "  连接时长: $(tail -n 100 "$work_dir/aios-cli.log" | grep -m 1 "Successfully connected to Hive" | cut -d']' -f1 | tr -d '[]')"
            else
                echo "  ✗ 未检测到心跳"
                # 如果没有心跳，尝试重新连接
                echo "  尝试重新建立连接..."
                AIOS_HOME="$work_dir" aios-cli kill > /dev/null 2>&1
                sleep 2
                AIOS_HOME="$work_dir" aios-cli start > /dev/null 2>&1 &
                sleep 3
                AIOS_HOME="$work_dir" aios-cli hive connect > /dev/null 2>&1 &
            fi
        fi

        echo "----------------------------------------------------------------"
    done

    echo
    echo "按任意键返回主菜单..."
    read -n 1 -s
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
