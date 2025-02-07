#!/bin/bash

SCRIPT_PATH="$HOME/Hyperspace.sh"

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
        echo "正在导入私钥..."
        aios-cli hive import-keys $tmpfile || echo "导入私钥失败，请检查私钥格式。"
        sleep 5
    else
        echo "未输入私钥，导入取消。"
    fi
    rm $tmpfile
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 修改后的部署函数（关键修改部分）
function deploy_hyperspace_node() {
    echo "开始部署 Hyperspace 节点..."
    
    # 执行安装命令
    echo "正在执行安装命令：curl https://download.hyper.space/api/install | bash"
    curl https://download.hyper.space/api/install | bash

    # 获取安装后新添加的路径
    NEW_PATH=$(bash -c 'source /root/.bashrc && echo $PATH')
    export PATH="$NEW_PATH"

    # 验证aios-cli是否可用
    if ! command -v aios-cli &> /dev/null; then
        echo "aios-cli 命令未找到，正在重试..."
        sleep 3
        export PATH="$PATH:/root/.local/bin"
        if ! command -v aios-cli &> /dev/null; then
            echo "无法找到 aios-cli 命令，请手动运行 'source /root/.bashrc' 后重试"
            read -n 1 -s -r -p "按任意键返回主菜单..."
            return
        fi
    fi

    # 清理旧的screen会话
    screen_name="node_$(date +%s)"
    echo "检查并清理现有的 '$screen_name' 屏幕会话..."
    screen -ls | grep "$screen_name" &>/dev/null
    if [ $? -eq 0 ]; then
        echo "找到现有会话，正在清理..."
        screen -S "$screen_name" -X quit
        sleep 2
    fi

    # 创建新的屏幕会话并启动服务
    echo "创建新的屏幕会话..."
    screen -S "$screen_name" -dm
    screen -S "$screen_name" -X stuff "aios-cli start\n"
    sleep 5

    # 确保环境变量已经生效
    echo "确保环境变量更新..."
    source /root/.bashrc
    sleep 4

    # 私钥导入逻辑
    echo "请输入私钥（按 CTRL+D 结束）："
    tmpfile=$(mktemp)
    cat > "$tmpfile"
    
    if [ -s "$tmpfile" ]; then
        echo "正在导入私钥..."
        if aios-cli hive import-keys "$tmpfile"; then
            echo "私钥导入成功！"
        else
            echo "私钥导入失败，请检查格式是否正确"
            rm "$tmpfile"
            read -n 1 -s -r -p "按任意键返回主菜单..."
            return
        fi
    else
        echo "未输入私钥，操作取消"
        rm "$tmpfile"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    fi
    rm "$tmpfile"

    # 定义模型变量并添加模型
    model="hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf"
    echo "正在添加模型..."
    
    retry_count=0
    max_retries=5
    
    while [ $retry_count -lt $max_retries ]; do
        if aios-cli models add "$model"; then
            echo "模型添加成功！"
            break
        else
            ((retry_count++))
            if [ $retry_count -lt $max_retries ]; then
                echo "添加模型失败，等待5秒后重试... (尝试 $retry_count/$max_retries)"
                aios-cli kill
                sleep 5
                screen -S "$screen_name" -X stuff "aios-cli start\n"
                sleep 5
            else
                echo "添加模型失败，请检查网络连接"
                read -n 1 -s -r -p "按任意键返回主菜单..."
                return
            fi
        fi
    done

    # 登录并选择等级
    echo "正在登录..."
    aios-cli hive login

    echo "请选择等级（1-5）："
    select tier in 1 2 3 4 5; do
        case $tier in
            1|2|3|4|5)
                echo "选择等级 $tier"
                aios-cli hive select-tier $tier
                break
                ;;
            *)
                echo "无效选择，请输入 1-5 之间的数字"
                ;;
        esac
    done

    # 连接到 Hive
    aios-cli hive connect
    sleep 5

    # 停止当前进程并重新启动
    echo "重启服务..."
    aios-cli kill
    sleep 2
    screen -S "$screen_name" -X stuff "aios-cli start --connect >> /root/aios-cli.log 2>&1\n"

    echo "节点部署完成！服务已在后台运行"
    echo "使用 'screen -r $screen_name' 可以查看运行状态"
    
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# ...（其他函数保持不变）...
