#!/bin/bash

SCRIPT_PATH="$HOME/Hyperspace.sh"
LOG_FILE="/root/aios-cli.log"

# 设置 RUST_BACKTRACE 以获取详细的回溯信息
export RUST_BACKTRACE=1

function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "================================================================"
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1. 部署hyperspace节点"
        echo "2. 查看日志"
        echo "3. 查看积分"
        echo "4. 删除节点（停止节点）"
        echo "5. 启用日志监控"
        echo "6. 查看使用的私钥"
        echo "7. 导入私钥"
        echo "8. 退出脚本"
        echo "================================================================"
        read -p "请输入选择 (1-8): " choice

        case $choice in
            1)  deploy_hyperspace_node ;;
            2)  view_logs ;; 
            3)  view_points ;;
            4)  delete_node ;;
            5)  start_log_monitor ;;
            6)  view_private_key ;;
            7)  import_private_key ;;
            8)  exit_script ;;
            *)  echo "无效选择，请重新输入！"; sleep 2 ;;
        esac
    done
}

# 新增私钥导入函数
function import_private_key() {
    tmpfile=$(mktemp)
    echo "请输入你的私钥（按 CTRL+D 结束）："
    cat > $tmpfile
    if [ -s $tmpfile ]; then
        echo "正在导入私钥..." | tee -a "$LOG_FILE"
        
        # 捕获命令输出
        import_output=$(aios-cli hive import-keys $tmpfile 2>&1)
        import_status=$?
        
        # 检查命令的退出状态
        if [ $import_status -ne 0 ]; then
            echo "导入私钥失败，错误码: $import_status" | tee -a "$LOG_FILE"
            echo "错误详情: $import_output" | tee -a "$LOG_FILE"
            echo "请检查私钥格式或联系支持。" | tee -a "$LOG_FILE"
        else
            echo "私钥导入成功！" | tee -a "$LOG_FILE"
        fi
        sleep 5
    else
        echo "未输入私钥，导入取消。" | tee -a "$LOG_FILE"
    fi
    rm $tmpfile
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 修改后的部署函数（关键修改部分）
function deploy_hyperspace_node() {
    echo "开始部署 Hyperspace 节点..."
    
    # 检查是否已有实例在运行
    if aios-cli status &>/dev/null; then
        echo "检测到已有实例在运行，请先停止现有实例。"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    fi

    # Prompt for a unique screen session name
    read -p "请输入一个唯一的屏幕会话名称 (例如: hyper1, hyper2): " screen_name
    if [ -z "$screen_name" ]; then
        echo "屏幕会话名称不能为空，请重试。"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    fi

    # 执行安装命令
    echo "正在执行安装命令：curl https://download.hyper.space/api/install | bash"
    curl https://download.hyper.space/api/install | bash

    # 更新环境变量
    source /root/.bashrc
    export PATH="$PATH:/root/.local/bin"
    
    # 验证aios-cli是否可用
    if ! command -v aios-cli &> /dev/null; then
        echo "aios-cli 命令未找到，请确保安装成功"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    fi

    # 清理旧的配置和进程
    echo "清理旧的配置和进程..."
    aios-cli kill 2>/dev/null
    sleep 2
    rm -rf ~/.local/share/aios-cli/* 2>/dev/null
    sleep 2

    # 初始化 aios-cli
    echo "初始化 aios-cli..."
    if ! aios-cli init; then
        echo "初始化失败，请检查系统环境"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    fi
    sleep 5

    # 启动守护进程
    echo "启动守护进程..."
    aios-cli start
    sleep 15  # 增加等待时间

    # 验证守护进程状态
    echo "验证守护进程状态..."
    for i in {1..3}; do
        if aios-cli status &>/dev/null; then
            break
        fi
        if [ $i -eq 3 ]; then
            echo "守护进程启动失败"
            read -n 1 -s -r -p "按任意键返回主菜单..."
            return
        fi
        echo "重试启动守护进程... ($i/3)"
        aios-cli kill
        sleep 5
        aios-cli start
        sleep 15
    done

    # 确保守护进程在导入私钥和添加模型之前运行
    if ! aios-cli status &>/dev/null; then
        echo "守护进程未运行，无法继续操作"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    fi

    # 多私钥导入逻辑
    while true; do
        echo "请输入私钥（按 CTRL+D 结束）："
        tmpfile=$(mktemp)
        cat > "$tmpfile"
        
        if [ -s "$tmpfile" ]; then
            echo "正在导入私钥..." | tee -a "$LOG_FILE"
            # 清理私钥格式
            sed -i 's/[[:space:]]*$//' "$tmpfile"
            sed -i '/^$/d' "$tmpfile"
            
            # 尝试多种方式导入私钥
            if ! aios-cli hive import-keys "$tmpfile" 2>/dev/null; then
                key_content=$(cat "$tmpfile")
                if ! echo "$key_content" | aios-cli hive import-keys - 2>/dev/null; then
                    echo "私钥导入失败，请确保格式正确"
                    rm "$tmpfile"
                    read -n 1 -s -r -p "按任意键返回主菜单..."
                    return
                fi
            fi
            echo "私钥导入成功！"
        else
            echo "未输入私钥"
            rm "$tmpfile"
            read -n 1 -s -r -p "按任意键返回主菜单..."
            return
        fi
        rm "$tmpfile"

        # 在每次导入私钥后，重置 aios-cli 状态
        echo "重置 aios-cli 状态..."
        aios-cli kill
        sleep 5
        aios-cli start
        sleep 15

        read -p "是否要导入另一个私钥？(y/n): " another_key
        if [[ "${another_key,,}" != "y" ]]; then
            break
        fi
    done

    # 添加模型
    echo "正在添加模型..."
    model="hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf"
    retry_count=0
    max_retries=3
    
    while [ $retry_count -lt $max_retries ]; do
        # 验证守护进程状态
        if ! aios-cli status &>/dev/null; then
            echo "守护进程未运行，重新启动..."
            aios-cli kill
            sleep 5
            aios-cli start
            sleep 15
        fi
        
        if aios-cli models add "$model" 2>/dev/null; then
            echo "模型添加成功！"
            break
        else
            ((retry_count++))
            if [ $retry_count -lt $max_retries ]; then
                echo "添加模型失败，等待15秒后重试... (尝试 $retry_count/$max_retries)"
                aios-cli kill
                sleep 5
                rm -rf ~/.local/share/aios-cli/models/* 2>/dev/null
                aios-cli start
                sleep 15
            else
                echo "添加模型失败，请检查网络连接"
                read -n 1 -s -r -p "按任意键返回主菜单..."
                return
            fi
        fi
    done

    # 登录和连接
    echo "正在登录..."
    if ! aios-cli hive login; then
        echo "登录失败"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    fi

    echo "请选择等级（1-5）："
    select tier in 1 2 3 4 5; do
        case $tier in
            1|2|3|4|5)
                if aios-cli hive select-tier $tier; then
                    echo "成功设置等级 $tier"
                    break
                else
                    echo "设置等级失败，请重试"
                fi
                ;;
            *)
                echo "无效选择，请输入 1-5 之间的数字"
                ;;
        esac
    done

    # 启动服务
    echo "启动服务..."
    aios-cli kill 2>/dev/null
    sleep 5
    if ! aios-cli start --connect; then
        echo "服务启动失败"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    fi

    # Create a new screen session for the node
    echo "创建一个名为 '$screen_name' 的屏幕会话..."
    screen -S "$screen_name" -dm

    # Run aios-cli start in the screen session
    echo "在屏幕会话 '$screen_name' 中运行 'aios-cli start --connect' 命令..."
    screen -S "$screen_name" -X stuff "aios-cli start --connect\n"

    echo "节点部署完成！服务已在后台运行"
    read -n 1 -s -r -p "按任意键返回主菜单..."
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
LOG_FILE="/root/aios-cli.log"
SCREEN_NAME="hyper"
LAST_RESTART=$(date +%s)
MIN_RESTART_INTERVAL=300

while true; do
    current_time=$(date +%s)
    
    # 检测到以下几种情况，触发重启
    if (tail -n 4 "$LOG_FILE" | grep -q "Last pong received.*Sending reconnect signal" || \
        tail -n 4 "$LOG_FILE" | grep -q "Failed to authenticate" || \
        tail -n 4 "$LOG_FILE" | grep -q "Failed to connect to Hive" || \
        tail -n 4 "$LOG_FILE" | grep -q "Another instance is already running" || \
        tail -n 4 "$LOG_FILE" | grep -q "\"message\": \"Internal server error\"" || \
        tail -n 4 "$LOG_FILE" | grep -q "thread 'main' panicked at aios-cli/src/main.rs:181:39: called \`Option::unwrap()\` on a \`None\` value") && \
       [ $((current_time - LAST_RESTART)) -gt $MIN_RESTART_INTERVAL ]; then
        echo "$(date): 检测到连接问题、认证失败、连接到 Hive 失败、实例已在运行、内部服务器错误或 'Option::unwrap()' 错误，正在重启服务..." >> /root/monitor.log
        
        # 先发送 Ctrl+C
        screen -S "$SCREEN_NAME" -X stuff $'\003'
        sleep 5
        
        # 执行 aios-cli kill
        screen -S "$SCREEN_NAME" -X stuff "aios-cli kill\n"
        sleep 5
        
        echo "$(date): 清理旧日志..." > "$LOG_FILE"
        
        # 重新启动服务
        screen -S "$SCREEN_NAME" -X stuff "aios-cli start --connect >> /root/aios-cli.log 2>&1\n"
        
        LAST_RESTART=$current_time
        echo "$(date): 服务已重启" >> /root/monitor.log
    fi
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

    # 提示用户按任意键返回主菜单
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
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

# 查看使用的私钥
function view_private_key() {
    echo "正在查看使用的私钥..."
    aios-cli hive whoami
    sleep 2

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
