#!/bin/bash

# 部署单个hyperspace节点
function deploy_single_node() {
    node_id=$1

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
        # 再次尝试更新PATH
        export PATH="$PATH:/root/.local/bin"
        if ! command -v aios-cli &> /dev/null; then
            echo "无法找到 aios-cli 命令，请手动运行 'source /root/.bashrc' 后重试"
            return
        fi
    fi

    # 提示输入屏幕名称，默认值为 'node_<id>'
    screen_name="node_$node_id"
    echo "使用的屏幕名称是: $screen_name"

    # 清理已存在的屏幕会话
    echo "检查并清理现有的 '$screen_name' 屏幕会话..."
    screen -ls | grep "$screen_name" &>/dev/null
    if [ $? -eq 0 ]; then
        echo "找到现有的 '$screen_name' 屏幕会话，正在停止并删除..."
        screen -S "$screen_name" -X quit
        sleep 2
    else
        echo "没有找到现有的 '$screen_name' 屏幕会话。"
    fi

    # 创建一个新的屏幕会话
    echo "创建一个名为 '$screen_name' 的屏幕会话..."
    screen -S "$screen_name" -dm

    # 在屏幕会话中启动 aiOs 守护进程
    echo "启动 aiOs 守护进程..."
    screen -S "$screen_name" -X stuff "aios-cli start\n"

    # 等待几秒钟确保守护进程已启动
    sleep 5

    # 提示用户输入私钥
    echo "请输入节点 $node_id 的私钥（按 CTRL+D 结束）："
    read private_key
    echo "$private_key" > "private_key_$node_id.pem"

    # 导入私钥
    echo "正在使用 private_key_$node_id.pem 文件运行 import-keys 命令..."
    aios-cli hive import-keys "./private_key_$node_id.pem"
    sleep 5

    # 如果导入失败，尝试启动守护进程
    if [[ $? -ne 0 ]]; then
        echo "导入私钥失败，尝试启动守护进程并重试..."
        screen -S "$screen_name" -X stuff "aios-cli start\n"
        sleep 10
        aios-cli hive import-keys "./private_key_$node_id.pem"
    fi

    # 确保守护进程已成功启动
    echo "确保守护进程已成功启动"
    screen -S "$screen_name" -X stuff "aios-cli start\n"
    sleep 5

    # 详细日志输出
    echo "设置 RUST_BACKTRACE 以便获取更多详细错误信息..."
    export RUST_BACKTRACE=1

    # 添加模型
    echo "正在通过命令 'aios-cli models add' 添加模型..."
    while true; do
        if aios-cli models add "hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf"; then
            echo "模型添加成功！"
            break
        else
            echo "添加模型时发生错误，正在重试..."
            sleep 3
        fi
    done

    # 登录并选择等级
    echo "正在登录并选择等级..."
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
    echo "使用 'aios-cli kill' 停止 'aios-cli start' 进程..."
    aios-cli kill

    # 在屏幕会话中运行 aios-cli start，并定向日志文件
    echo "在屏幕会话 '$screen_name' 中运行 'aios-cli start --connect'，并将输出定向到 '/root/aios-cli.log'..."
    screen -S "$screen_name" -X stuff "aios-cli start --connect >> /root/aios-cli.log 2>&1\n"

    echo "节点 $node_id 部署完成，'aios-cli start --connect' 已在屏幕内运行，系统已恢复到后台。"
}

# 退出脚本
function exit_script() {
    echo "退出脚本..."
    exit 0
}

# 启动主菜单
function main_menu() {
    while true; do
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
            1)
                read -p "请输入要部署的节点数量: " num_nodes
                for i in $(seq 1 $num_nodes); do
                    deploy_single_node $i
                done
                ;;
            2)
                echo "查看日志功能待实现"
                ;;
            3)
                echo "查看积分功能待实现"
                ;;
            4)
                echo "删除节点功能待实现"
                ;;
            5)
                echo "启用日志监控功能待实现"
                ;;
            6)
                echo "查看使用的私钥功能待实现"
                ;;
            7)
                exit_script
                ;;
            *)
                echo "无效选择，请重新输入。"
                ;;
        esac
    done
}

# 启动脚本
main_menu
