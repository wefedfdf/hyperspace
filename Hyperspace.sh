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
    # ...（保持原有安装流程不变）...

    # 多私钥导入逻辑
    echo "现在开始导入私钥，可以导入多个私钥。"
    while true; do
        tmpfile=$(mktemp)
        echo "请输入你的私钥（按 CTRL+D 结束）："
        cat > $tmpfile
        if [ -s $tmpfile ]; then
            echo "正在导入私钥..."
            aios-cli hive import-keys $tmpfile || echo "导入私钥失败，请检查私钥格式。"
            sleep 5
        else
            echo "未输入私钥，跳过导入。"
        fi
        rm $tmpfile
        read -p "是否要导入另一个私钥？(y/n): " another_key
        if [[ "${another_key,,}" != "y" ]]; then
            break
        fi
    done

    # ...（后续保持原有模型添加和节点启动逻辑不变）...
}

# ...（其他函数保持不变）...
