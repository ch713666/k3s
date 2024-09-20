#!/bin/bash

# 定义标志文件路径
status_file="/var/log/tailscale_install_status.log"

# 定义一个简单的进度函数
progress() {
    echo "[$1/$2] $3"
}

# 检查 Tailscale 是否已经安装
has_installed() {
    if [[ -f "$status_file" ]]; then
        echo "Tailscale 已安装，跳过此步骤。"
        return 0
    else
        return 1
    fi
}

# 标记 Tailscale 安装成功
mark_as_installed() {
    echo "Tailscale 安装成功。" > "$status_file"
}

# 如果已经安装则跳过
if has_installed; then
    exit 0
fi

total_steps=1
step=1

# 安装 Tailscale
while true; do
    progress $step $total_steps "正在安装 Tailscale..."
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://mirrors.ysicing.net/tailscale/stable/debian bookworm main" | sudo tee /etc/apt/sources.list.d/tailscale.list
    sudo apt-get update
    
    # 如果安装成功，标记安装状态并退出循环
    if sudo apt-get install -y tailscale; then
        echo "Tailscale 安装完成。"
        mark_as_installed
        break
    else
        echo "Tailscale 安装失败，正在重试..."
        sleep 5  # 等待5秒后重试
    fi
done
