#!/bin/bash

# 定义一个简单的进度函数
progress() {
    echo "[$1/$2] $3"
}

# 定义进度条显示函数
progress_bar() {
    local duration=$1
    local interval=0.1
    local total=$((duration / interval))
    
    for ((i=0; i<=total; i++)); do
        local progress=$((i * 100 / total))
        printf "\r进度: ["
        for ((j=0; j<progress / 2; j++)); do
            printf "█"
        done
        for ((j=progress / 2; j<50; j++)); do
            printf " "
        done
        printf "] %d%%" "$progress"
        sleep "$interval"
    done
    echo ""
}

total_steps=12
step=1

# 获取公网IP地址
public_ip=$(curl -s ifconfig.me)

# 根据公网IP判断并设置计算机名
progress $step $total_steps "正在检测公网IP并设置计算机名..."
if [[ $public_ip == "1.94.57.193" ]]; then
    hostnamectl set-hostname hw-cn-master-01.3idp.com
    echo "计算机名已更改为: hw-cn-master-01.3idp.com (IP: $public_ip)"
elif [[ $public_ip == "117.72.66.130" ]]; then
    hostnamectl set-hostname jd-cn-master-02.3idp.com
    echo "计算机名已更改为: jd-cn-master-02.3idp.com (IP: $public_ip)"
elif [[ $public_ip == "14.103.92.254" ]]; then
    hostnamectl set-hostname hs-cn-master-03.3idp.com
    echo "计算机名已更改为: hs-cn-master-03.3idp.com (IP: $public_ip)"
else
    echo "未找到匹配的公网IP，跳过主机名更改。当前IP: $public_ip"
fi

step=$((step + 1))

# 设置防火墙
progress $step $total_steps "正在设置防火墙..."
sudo ufw enable
sudo ufw status
sudo ufw allow proto tcp from any to any port 22 # ssh
sudo ufw allow proto tcp from any to any port 6443 # k3s api
sudo ufw allow proto tcp from any to any port 10250 # kubelet metrics
echo "防火墙规则已应用。"
step=$((step + 1))

# 设置转发
progress $step $total_steps "正在设置网络转发..."
sudo iptables --policy FORWARD ACCEPT
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
echo "网络转发已配置。"
step=$((step + 1))

# 设置BBR加速
progress $step $total_steps "正在设置BBR加速..."
uname -r
echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
echo "BBR加速已启用。"
step=$((step + 1))

# 设置国内更新源
progress $step $total_steps "正在设置国内更新源..."
sudo mv /etc/apt/sources.list /etc/apt/sources.list.bak
sudo tee /etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
EOF
echo "国内更新源已配置。"
step=$((step + 1))

# 系统更新
progress $step $total_steps "正在更新系统..."
sudo apt update
sudo apt upgrade -y
echo "系统更新已完成。"
