#!/bin/bash

# 定义记录文件
STATUS_FILE="./install_status.txt"

# 检查是否已经执行过
check_status() {
    if [[ -f $STATUS_FILE ]]; then
        echo "安装已完成，跳过后续步骤。"
        exit 0
    fi
}

# 定义函数：自动安装
auto_install() {
    echo "开始自动安装..."
    # 您可以在此添加所有自动安装步骤
    echo "自动安装完成。"
    touch $STATUS_FILE  # 创建状态文件
}

# 定义函数：系统配置
configure_system() {
    echo "开始下载并执行系统配置脚本..."
    curl -O https://github.com/ch713666/k3s/blob/main/%E8%84%9A%E6%9C%AC/Ubuntu.sh
    chmod +x Ubuntu.sh
    ./Ubuntu.sh
    touch $STATUS_FILE  # 创建状态文件
}

# 定义函数：安装Tailscale
install_tailscale() {
    echo "开始下载并执行Tailscale安装脚本..."
    curl -O https://github.com/ch713666/k3s/blob/main/%E8%84%9A%E6%9C%AC/tailscale.sh
    chmod +x tailscale.sh
    ./tailscale.sh
    touch $STATUS_FILE  # 创建状态文件
}

# 定义函数：安装Docker
install_docker() {
    echo "开始下载并执行Docker安装脚本..."
    curl -O https://github.com/ch713666/k3s/blob/main/%E8%84%9A%E6%9C%AC/Docker.sh
    chmod +x Docker.sh
    ./Docker.sh
    touch $STATUS_FILE  # 创建状态文件
}

# 定义函数：安装K3s
install_k3s() {
    echo "请选择K3s安装选项："
    echo "1. 安装第一台Master"
    echo "2. 安装Master"
    echo "3. 安装Agent"
    read -p "请输入选择的数字(1-3): " k3s_choice

    case $k3s_choice in
        1)
            echo "开始安装第一台Master节点..."
            curl -O https://github.com/ch713666/k3s/blob/main/%E8%84%9A%E6%9C%AC/k3s-install-master.sh
            chmod +x k3s-install-master.sh
            ./k3s-install-master.sh
            ;;
        2)
            echo "开始安装Master节点..."
            curl -O https://github.com/ch713666/k3s/blob/main/%E8%84%9A%E6%9C%AC/k3s-install-master.sh
            chmod +x k3s-install-master.sh
            ./k3s-install-master.sh
            ;;
        3)
            echo "开始安装Agent节点..."
            curl -O https://github.com/ch713666/k3s/blob/main/%E8%84%9A%E6%9C%AC/k3s-install-agent.sh
            chmod +x k3s-install-agent.sh
            ./k3s-install-agent.sh
            ;;
        *)
            echo "无效的选择，请输入1-3之间的数字。"
            ;;
    esac
    touch $STATUS_FILE  # 创建状态文件
}

# 分步安装菜单
step_install() {
    check_status  # 检查是否已执行过

    echo "请选择分步安装项："
    echo "1. 系统配置"
    echo "2. 安装Tailscale"
    echo "3. 安装Docker"
    echo "4. 安装K3s"
    read -p "请输入选择的数字(1-4): " step_choice

    case $step_choice in
        1)
            configure_system
            ;;
        2)
            install_tailscale
            ;;
        3)
            install_docker
            ;;
        4)
            install_k3s
            ;;
        *)
            echo "无效的选择，请输入1-4之间的数字。"
            ;;
    esac
}

# 主菜单
echo "请选择安装模式："
echo "1. 自动安装"
echo "2. 分步安装"
read -p "请输入选择的数字(1或2): " choice

case $choice in
    1)
        check_status  # 检查是否已执行过
        auto_install
        ;;
    2)
        step_install
        ;;
    *)
        echo "无效的选择，请输入1或2。"
        ;;
esac
