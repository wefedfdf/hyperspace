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

    # 获取安装后新添加的路径并更新环境
    source /root/.bashrc
    
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

    # 确保守护进程已停止
    echo "停止可能运行的守护进程..."
    aios-cli kill 2>/dev/null
    sleep 5

    # 启动守护进程
    echo "启动守护进程..."
    aios-cli start
    sleep 10  # 给守护进程足够的启动时间

    # 验证守护进程状态
    if ! aios-cli status &>/dev/null; then
        echo "守护进程启动失败，尝试重新启动..."
        aios-cli kill
        sleep 5
        aios-cli start
        sleep 10
        if ! aios-cli status &>/dev/null; then
            echo "无法启动守护进程，请检查系统环境"
            read -n 1 -s -r -p "按任意键返回主菜单..."
            return
        fi
    fi

    # 私钥导入逻辑
    echo "请输入私钥（按 CTRL+D 结束）："
    tmpfile=$(mktemp)
    cat > "$tmpfile"
    
    if [ -s "$tmpfile" ]; then
        echo "正在导入私钥..."
        # 确保私钥文件格式正确（移除可能的空行和空格）
        sed -i 's/[[:space:]]*$//' "$tmpfile"
        if aios-cli hive import-keys "$tmpfile" 2>/dev/null; then
            echo "私钥导入成功！"
        else
            echo "私钥导入失败，尝试替代方法..."
            # 尝试直接使用私钥内容
            key_content=$(cat "$tmpfile")
            if echo "$key_content" | aios-cli hive import-keys -; then
                echo "私钥导入成功！"
            else
                echo "私钥导入失败，请检查格式是否正确"
                rm "$tmpfile"
                read -n 1 -s -r -p "按任意键返回主菜单..."
                return
            fi
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
        # 确保守护进程运行
        if ! aios-cli status &>/dev/null; then
            echo "守护进程未运行，重新启动..."
            aios-cli start
            sleep 10
        fi
        
        if aios-cli models add "$model" 2>/dev/null; then
            echo "模型添加成功！"
            break
        else
            ((retry_count++))
            if [ $retry_count -lt $max_retries ]; then
                echo "添加模型失败，等待10秒后重试... (尝试 $retry_count/$max_retries)"
                aios-cli kill
                sleep 5
                aios-cli start
                sleep 10
            else
                echo "添加模型失败，请检查网络连接"
                read -n 1 -s -r -p "按任意键返回主菜单..."
                return
            fi
        fi
    done

    # 登录并选择等级
    echo "正在登录..."
    if ! aios-cli hive login; then
        echo "登录失败，请检查网络连接和私钥"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    fi

    echo "请选择等级（1-5）："
    select tier in 1 2 3 4 5; do
        case $tier in
            1|2|3|4|5)
                echo "选择等级 $tier"
                if aios-cli hive select-tier $tier; then
                    break
                else
                    echo "设置等级失败，请重试"
                    continue
                fi
                ;;
            *)
                echo "无效选择，请输入 1-5 之间的数字"
                ;;
        esac
    done

    # 连接到 Hive
    echo "连接到 Hive..."
    if ! aios-cli hive connect; then
        echo "连接失败，请检查网络状态"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    fi
    sleep 5

    # 启动服务
    echo "启动服务..."
    aios-cli kill 2>/dev/null
    sleep 2
    aios-cli start --connect

    echo "节点部署完成！服务已在后台运行"
    
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# ...（其他函数保持不变）...
