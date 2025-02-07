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
    
    # 检查 aios-cli 是否安装
    if ! command -v aios-cli &> /dev/null; then
        echo "错误: aios-cli 未安装或不在系统路径中"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    }
    
    # 初始化 aios-cli
    echo "初始化 aios-cli..."
    aios-cli init || {
        echo "初始化 aios-cli 失败"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    }
    
    # 检查并启动守护进程
    echo "检查并启动守护进程..."
    aios-cli start
    sleep 10  # 增加等待时间，确保守护进程完全启动
    
    # 验证守护进程状态
    if ! aios-cli status &> /dev/null; then
        echo "错误: 守护进程未能正常启动"
        read -n 1 -s -r -p "按任意键返回主菜单..."
        return
    }
    
    # 清理旧的screen会话
    screen -wipe > /dev/null 2>&1
    screen_name="node_$(date +%s)"
    echo "检查并清理现有的 '$screen_name' 屏幕会话..."
    screen -S "$screen_name" -X quit > /dev/null 2>&1
    
    # 私钥导入逻辑
    echo "现在开始导入私钥..."
    while true; do
        tmpfile=$(mktemp)
        echo "请输入私钥（按 CTRL+D 结束）："
        cat > "$tmpfile"
        if [ -s "$tmpfile" ]; then
            echo "正在导入私钥..."
            # 设置 RUST_BACKTRACE 以获取更详细的错误信息
            export RUST_BACKTRACE=1
            if RUST_BACKTRACE=1 aios-cli hive import-keys "$tmpfile" 2>&1; then
                echo "私钥导入成功！"
            else
                echo "私钥导入失败，请确保私钥格式正确"
                rm "$tmpfile"
                read -p "是否重试？(y/n): " retry
                if [[ "${retry,,}" == "y" ]]; then
                    continue
                fi
            fi
        else
            echo "未输入私钥，跳过导入。"
        fi
        rm "$tmpfile"
        
        read -p "是否要导入另一个私钥？(y/n): " another_key
        if [[ "${another_key,,}" != "y" ]]; then
            break
        fi
    done
    
    # 添加模型前先验证环境
    echo "验证环境..."
    if ! aios-cli status &> /dev/null; then
        echo "错误: 守护进程未响应，尝试重启..."
        aios-cli start
        sleep 10
    }
    
    # 添加模型
    echo "正在添加模型..."
    max_retries=3
    retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        export RUST_BACKTRACE=1
        if RUST_BACKTRACE=1 aios-cli models add 2>&1; then
            echo "模型添加成功！"
            break
        else
            ((retry_count++))
            if [ $retry_count -lt $max_retries ]; then
                echo "添加模型失败，等待10秒后重试... (尝试 $retry_count/$max_retries)"
                # 重启守护进程
                aios-cli stop
                sleep 5
                aios-cli start
                sleep 10
            else
                echo "添加模型失败，请检查系统环境并重试"
                read -n 1 -s -r -p "按任意键返回主菜单..."
                return
            fi
        fi
    done
    
    # 启动节点
    echo "正在启动节点..."
    if screen -dmS "$screen_name" aios-cli hive start; then
        echo "节点已成功启动！"
        echo "使用 'screen -r $screen_name' 可以查看节点运行状态"
    else
        echo "节点启动失败，请检查日志"
    fi
    
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# ...（其他函数保持不变）...
