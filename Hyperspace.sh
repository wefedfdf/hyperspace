#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Hyperspace.sh"

# 在文件开头添加配置目录定义
HYPERSPACE_CONFIG_DIR="$HOME/.hyperspace"
NODES_INFO_FILE="$HYPERSPACE_CONFIG_DIR/nodes_info.txt"

# 在 main_menu 函数之前添加初始化函数
function init_config() {
    mkdir -p "$HYPERSPACE_CONFIG_DIR/keys"
    touch "$NODES_INFO_FILE"
}

# 主菜单函数
function main_menu() {
    init_config
    
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "================================================================"
        echo "退出脚本1，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1. 部署hypers节点26"
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
    
    if [ -f "$NODES_INFO_FILE" ]; then
        while IFS='|' read -r node_num work_dir key_file; do
            if [ -d "$work_dir" ]; then
                echo "节点 $node_num:"
                AIOS_HOME="$work_dir" aios-cli hive whoami 2>/dev/null
                echo "------------------------"
            fi
        done < "$NODES_INFO_FILE"
    else
        echo "未找到任何节点信息"
    fi
    
    read -n 1 -s -r -p "按任意键继续..."
}

# 清理 PATH 环境变量的函数
function clean_path() {
    PATH=$(echo $PATH | tr ':' '\n' | awk '!seen[$0]++' | tr '\n' ':' | sed 's/:$//')
}

# 检查并清理进程的函数
function cleanup_processes() {
    local work_dir=$1
    local screen_name=$2
    echo "清理进程..."
    
    # 清理所有相关的 screen 会话
    for session in $(screen -ls | grep "$screen_name" | awk '{print $1}'); do
        screen -S "$session" -X quit
    done
    
    # 停止 aios-cli 进程
    if AIOS_HOME="$work_dir" aios-cli kill 2>/dev/null; then
        echo "成功停止守护进程"
    fi
    
    # 强制结束残留进程
    pkill -9 -f "AIOS_HOME=$work_dir aios-cli" 2>/dev/null
    
    # 等待进程完全停止
    sleep 3
    return 0
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

# 选择等级的函数
function select_tier() {
    local work_dir=$1
    local node_num=$2
    
    # 确保守护进程在运行
    if ! AIOS_HOME="$work_dir" aios-cli status | grep -q "running"; then
        echo "启动守护进程..."
        AIOS_HOME="$work_dir" aios-cli start > "$work_dir/init.log" 2>&1 &
        sleep 5
    fi

    # 确保已登录
    echo "确保登录状态..."
    if ! AIOS_HOME="$work_dir" aios-cli hive login 2>&1; then
        echo "错误：登录失败"
        return 1
    fi
    
    # 选择等级
    local tier_selected=false
    while ! $tier_selected; do
        echo "请为节点 $node_num 选择等级（1-5）："
        select tier in 1 2 3 4 5; do
            if [[ "$tier" =~ ^[1-5]$ ]]; then
                if AIOS_HOME="$work_dir" aios-cli hive select-tier "$tier" 2>&1 | grep -q "Successfully"; then
                    tier_selected=true
                    break
                else
                    echo "该等级不可用，请选择其他等级"
                fi
            else
                echo "请选择有效的等级（1-5）"
            fi
        done
    done
}

# 部署单个节点的函数
function deploy_single_node() {
    local node_num=$1
    local screen_name="hyper_${node_num}"
    local work_dir="/root/.aios_node${node_num}"
    
    echo "=== 开始部署节点 $node_num ==="
    
    # 创建并设置工作目录
    mkdir -p "$work_dir"
    export AIOS_HOME="$work_dir"

    # 清理 PATH 和已有进程
    clean_path
    cleanup_processes "$work_dir" "$screen_name"

    # 创建私钥文件
    mkdir -p "$HOME/.hyperspace/keys"
    local key_file="$HOME/.hyperspace/keys/node${node_num}_$(date +%s).pem"

    # 获取私钥
    echo "请输入节点 $node_num 的私钥（按 CTRL+D 结束）："
    if ! cat > "$key_file"; then
        echo "错误：私钥保存失败"
        rm -f "$key_file"
        return 1
    fi

    chmod 600 "$key_file"

    # 初始化节点
    echo "初始化节点..."
    AIOS_HOME="$work_dir" aios-cli start > "$work_dir/init.log" 2>&1 &
    sleep 5

    # 导入私钥并登录
    echo "导入私钥并登录..."
    if ! AIOS_HOME="$work_dir" aios-cli hive import-keys "$key_file" 2>&1 || \
       ! AIOS_HOME="$work_dir" aios-cli hive login 2>&1; then
        echo "错误：私钥导入或登录失败"
        cleanup_processes "$work_dir" "$screen_name"
        return 1
    fi

    # 选择等级
    if ! select_tier "$work_dir" "$node_num"; then
        echo "错误：无法设置节点等级"
        cleanup_processes "$work_dir" "$screen_name"
        return 1
    fi

    # 启动节点
    echo "启动节点..."
    screen -dmS "$screen_name"
    screen -S "$screen_name" -X stuff "AIOS_HOME=$work_dir aios-cli start --connect >> $work_dir/aios-cli.log 2>&1\n"

    # 等待节点启动
    echo "等待节点启动..."
    local start_time=$(date +%s)
    local timeout=60  # 60秒超时
    local connected=false

    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
        if tail -n 50 "$work_dir/aios-cli.log" 2>/dev/null | grep -q "Successfully allocated VRAM" || \
           tail -n 50 "$work_dir/aios-cli.log" 2>/dev/null | grep -q "Received pong"; then
            connected=true
            break
        fi
        sleep 5
        echo -n "."
    done
    echo

    if $connected; then
        echo "节点 $node_num 启动成功！"
        # 记录节点信息
        echo "${node_num}|${work_dir}|${key_file}" >> "$NODES_INFO_FILE"
        echo "=== 节点 $node_num 部署完成 ==="
        return 0
    else
        echo "错误：节点启动超时"
        cleanup_processes "$work_dir" "$screen_name"
        return 1
    fi
}

# 查看积分
function view_points() {
    echo "正在查询所有节点积分..."
    echo "=================================="
    
    if [ ! -f "$NODES_INFO_FILE" ]; then
        echo "未找到已部署的节点信息"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    fi

    # 创建临时文件存储积分信息
    local temp_file=$(mktemp)
    
    # 读取并显示每个节点的积分
    while IFS='|' read -r node_num work_dir key_file; do
        if [ -d "$work_dir" ]; then
            echo "节点 $node_num 的积分信息：" | tee -a "$temp_file"
            echo "------------------------" | tee -a "$temp_file"
            if AIOS_HOME="$work_dir" aios-cli hive points 2>&1 | tee -a "$temp_file"; then
                echo "查询成功"
            else
                echo "查询失败，可能需要重新启动节点" | tee -a "$temp_file"
            fi
            echo "------------------------" | tee -a "$temp_file"
        fi
    done < "$NODES_INFO_FILE"

    # 显示汇总信息
    echo -e "\n积分汇总："
    echo "=================================="
    grep -A 1 "Points:" "$temp_file" | grep -v "^--$"
    
    # 清理临时文件
    rm -f "$temp_file"

    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# 删除节点（停止节点）
function delete_node() {
    echo "请选择要删除的节点："
    echo "0. 删除所有节点"
    
    # 显示所有节点
    if [ -f "$NODES_INFO_FILE" ]; then
        while IFS='|' read -r node_num work_dir key_file; do
            echo "$node_num. 节点 $node_num (工作目录: $work_dir)"
        done < "$NODES_INFO_FILE"
    fi

    read -p "请输入节点编号: " selected_node

    if [ "$selected_node" = "0" ]; then
        echo "正在删除所有节点..."
        while IFS='|' read -r node_num work_dir key_file; do
            AIOS_HOME="$work_dir" aios-cli kill 2>/dev/null
            remove_node_info "$node_num"
        done < "$NODES_INFO_FILE"
        > "$NODES_INFO_FILE"
    elif [ -n "$selected_node" ]; then
        while IFS='|' read -r node_num work_dir key_file; do
            if [ "$node_num" = "$selected_node" ]; then
                echo "正在删除节点 $node_num..."
                AIOS_HOME="$work_dir" aios-cli kill 2>/dev/null
                remove_node_info "$node_num"
                break
            fi
        done < "$NODES_INFO_FILE"
    fi

    echo "节点删除完成"
    read -n 1 -s -r -p "按任意键返回主菜单..."
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

check_node_status() {
    local work_dir=$1
    local log_file="$work_dir/aios-cli.log"
    
    # 检查最近的日志
    if tail -n 50 "$log_file" 2>/dev/null | grep -q "Received pong"; then
        # 检查最后一次 pong 时间
        local last_pong=$(tail -n 50 "$log_file" | grep "Received pong" | tail -n 1 | cut -d'[' -f2 | cut -d']' -f1)
        local last_pong_ts=$(date -d "$last_pong" +%s 2>/dev/null)
        local current_time=$(date +%s)
        
        if [ $((current_time - last_pong_ts)) -lt 300 ]; then
            return 0  # 节点正常
        fi
    fi
    return 1  # 节点需要重启
}

while true; do
    for screen_name in $(get_node_screens); do
        node_num=$(echo "$screen_name" | cut -d'_' -f2)
        work_dir="/root/.aios_node${node_num}"
        
        if ! check_node_status "$work_dir"; then
            echo "$(date): 节点 $node_num 需要重启..." >> /root/monitor.log
            
            cleanup_processes "$work_dir" "$screen_name"
            sleep 5
            
            # 重新初始化和启动
            AIOS_HOME="$work_dir" aios-cli start > "$work_dir/init.log" 2>&1 &
            sleep 5
            
            screen -S "$screen_name" -X stuff "AIOS_HOME=$work_dir aios-cli start --connect >> $work_dir/aios-cli.log 2>&1\n"
            
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

# 添加清理节点信息的函数
function remove_node_info() {
    local node_num=$1
    if [ -f "$NODES_INFO_FILE" ]; then
        sed -i "/^${node_num}|/d" "$NODES_INFO_FILE"
    fi
}

# 调用主菜单函数
main_menu
