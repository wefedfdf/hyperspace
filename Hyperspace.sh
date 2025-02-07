#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Hyperspace.sh"

# 启动 aiOS 守护进程
function start_daemon() {
    echo "启动 aiOS 守护进程..."
    # 启动 aiOS 守护进程
    aios-cli start
    sleep 5  # 等待守护进程启动
}

# 导入私钥
function import_private_key() {
    local private_key_file=$1
    echo "正在导入私钥: $private_key_file..."
    if ! aios-cli hive import-keys "$private_key_file"; then
        echo "导入私钥失败，请检查私钥格式或守护进程状态"
        return 1
    fi
    echo "私钥导入成功！"
    return 0
}

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "================================================================"
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1. 部署多个hyperspace节点"
        echo "2. 查看日志"
        echo "3. 查看积分"
        echo "4. 删除节点（停止节点）"
        echo "5. 启用日志监控"
        echo "6. 查看使用的私钥"
        echo "7. 退出脚本"
        echo "================================================================"
        read -p "请输入选择 (1/2/3/4/5/6/7): " choice

        case $choice in
            1)  deploy_multiple_nodes ;;
            2)  view_logs ;; 
            3)  view_points ;;
            4)  delete_node ;;
            5)  start_log_monitor ;;
            6)  view_private_key ;;
            7)  exit_script ;;
            *)  echo "无效选择，请重新输入！"; sleep 2 ;;
        esac
    done
}

# 部署多个hyperspace节点
function deploy_multiple_nodes() {
    read -p "请输入要部署的节点数量: " node_count
    for i in $(seq 1 $node_count); do
        echo "部署节点 $i..."
        deploy_hyperspace_node $i
    done
    echo "所有节点部署完成！"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 部署单个hyperspace节点
function deploy_hyperspace_node() {
    local node_id=$1

    # 执行安装命令
    echo "正在执行安装命令：curl https://download.hyper.space/api/install | bash"
    curl https://download.hyper.space/api/install | bash

    # 启动守护进程
    start_daemon

    # 提示用户输入私钥，使用不同的私钥文件
    read -p "请输入节点 $node_id 的私钥（按 CTRL+D 结束）: " private_key
    private_key_file="private_key_$node_id.pem"
    echo "$private_key" > "$private_key_file"

    # 导入私钥
    import_private_key "$private_key_file"
    if [ $? -ne 0 ]; then
        echo "私钥导入失败，节点 $node_id 部署失败！"
        return
    fi

    # 添加模型
    model="hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf"
    echo "正在通过命令 'aios-cli models add' 添加模型..."
    while true; do
        if aios-cli models add "$model"; then
            echo "模型添加成功并且下载完成！"
            break
        else
            echo "添加模型时发生错误，正在重试..."
            sleep 3
        fi
    done

    # 登录并选择等级
    aios-cli hive login
    echo "请选择等级（1-5）："
    select tier in 1 2 3 4 5; do
        case $tier in
            1|2|3|4|5)
                echo "你选择了等级 $tier"
                aios-cli hive select-tier $tier
                break
                ;;
            *)
                echo "无效的选择，请输入 1 到 5 之间的数字。"
                ;;
        esac
    done

    # 连接到 Hive
    aios-cli hive connect
    sleep 5

    # 停止 aios-cli 进程
    aios-cli kill

    # 在屏幕会话中运行 aios-cli start，并定向日志文件
    screen_name="node_$node_id"
    echo "在屏幕会话 '$screen_name' 中运行 'aios-cli start --connect'，并将输出定向到 '/root/aios-cli_$node_id.log'..."
    screen -S "$screen_name" -dm
    screen -S "$screen_name" -X stuff "aios-cli start --connect >> /root/aios-cli_$node_id.log 2>&1\n"

    echo "节点 $node_id 部署完成，'aios-cli start --connect' 已在屏幕内运行，系统已恢复到后台。"
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
    aios-cli kill
    sleep 2
    echo "'aios-cli kill' 执行完成，节点已停止。"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 启用日志监控
function start_log_monitor() {
    echo "启动日志监控..."
    cat > /root/monitor.sh << 'EOL'
#!/bin/bash
LOG_FILE="/root/aios-cli.log"
SCREEN_NAME="hyper"
LAST_RESTART=$(date +%s)
MIN_RESTART_INTERVAL=300

while true; do
    current_time=$(date +%s)
    
    if (tail -n 4 "$LOG_FILE" | grep -q "Last pong received.*Sending reconnect signal" || \
        tail -n 4 "$LOG_FILE" | grep -q "Failed to authenticate" || \
        tail -n 4 "$LOG_FILE" | grep -q "Failed to connect to Hive" || \
        tail -n 4 "$LOG_FILE" | grep -q "Another instance is already running" || \
        tail -n 4 "$LOG_FILE" | grep -q "\"message\": \"Internal server error\"" || \
        tail -n 4 "$LOG_FILE" | grep -q "thread 'main' panicked at aios-cli/src/main.rs:181:39: called \`Option::unwrap()\` on a \`None\` value") && \
       [ $((current_time - LAST_RESTART)) -gt $MIN_RESTART_INTERVAL ]; then
        echo "$(date): 检测到连接问题、认证失败、连接到 Hive 失败、实例已在运行、内部服务器错误或 'Option::unwrap()' 错误，正在重启服务..." >> /root/monitor.log
        
        screen -S "$SCREEN_NAME" -X stuff $'\003'
        sleep 5
        screen -S "$SCREEN_NAME" -X stuff "aios-cli kill\n"
        sleep 5
        
        echo "$(date): 清理旧日志..." > "$LOG_FILE"
        screen -S "$SCREEN_NAME" -X stuff "aios-cli start --connect >> /root/aios-cli.log 2>&1\n"
        
        LAST_RESTART=$current_time
        echo "$(date): 服务已重启" >> /root/monitor.log
    fi
    sleep 30
done
EOL

    chmod +x /root/monitor.sh
    nohup /root/monitor.sh > /root/monitor.log 2>&1 &
    echo "日志监控已启动，后台运行中。"
    sleep 2
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 查看使用的私钥
function view_private_key() {
    echo "正在查看使用的私钥..."
    aios-cli hive whoami
    sleep 2
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 退出脚本
function exit_script() {
    echo "退出脚本..."
    exit 0
}

# 执行主菜单
main_menu
