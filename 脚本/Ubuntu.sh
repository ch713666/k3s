#!/bin/bash

# 定义状态文件
status_file="$HOME/script_status.log"

# 定义一个简单的进度函数
progress() {
    echo "[$1/$2] $3"
}

# 定义一个错误重试函数
retry() {
    local retries=3
    local count=0
    local delay=5 # 等待5秒再重试
    local command="$1"

    until eval "$command"; do
        count=$((count + 1))
        if [[ $count -ge $retries ]]; then
            echo "尝试 $retries 次后，任务失败。"
            return 1
        fi
        echo "任务失败，$delay 秒后重试 ($count/$retries)..."
        sleep $delay
    done

    return 0
}

# 检查是否已经执行过某个步骤
has_run() {
    grep -q "$1" "$status_file"
}

# 标记步骤已经成功运行
mark_as_run() {
    echo "$1" >> "$status_file"
}

# 确保状态文件存在
touch "$status_file"

# 获取公网IP地址
public_ip=$(curl -s ifconfig.me)
if [[ -z "$public_ip" ]]; then
    echo "无法获取公网IP，退出脚本。"
    exit 1
fi

# 总步骤数
total_steps=6
step=1

# 检查并设置计算机名
if has_run "set_hostname"; then
    echo "步骤[$step]: 计算机名已设置，跳过。"
else
    progress $step $total_steps "正在检测公网IP并设置计算机名..."
    retry "if [[ \$public_ip == '1.94.57.193' ]]; then
        hostnamectl set-hostname hw-cn-master-01.3idp.com &&
        echo '计算机名已更改为: hw-cn-master-01.3idp.com (IP: \$public_ip)'
    elif [[ \$public_ip == '117.72.66.130' ]]; then
        hostnamectl set-hostname jd-cn-master-02.3idp.com &&
        echo '计算机名已更改为: jd-cn-master-02.3idp.com (IP: \$public_ip)'
    elif [[ \$public_ip == '14.103.92.254' ]]; then
        hostnamectl set-hostname hs-cn-master-03.3idp.com &&
        echo '计算机名已更改为: hs-cn-master-03.3idp.com (IP: \$public_ip)'
    else
        echo '未找到匹配的公网IP，跳过主机名更改。当前IP: \$public_ip'
    fi" || exit 1
    mark_as_run "set_hostname"
fi
step=$((step + 1))

# 设置防火墙
if has_run "setup_firewall"; then
    echo "步骤[$step]: 防火墙已设置，跳过。"
else
    progress $step $total_steps "正在设置防火墙..."
    retry "ufw enable &&
    ufw status &&
    ufw allow proto tcp from any to any port 22 &&
    ufw allow proto tcp from any to any port 6443 &&
    ufw allow proto tcp from any to any port 10250" || exit 1
    echo "防火墙规则已应用。"
    mark_as_run "setup_firewall"
fi
step=$((step + 1))

# 设置网络转发
if has_run "setup_forwarding"; then
    echo "步骤[$step]: 网络转发已设置，跳过。"
else
    progress $step $total_steps "正在设置网络转发..."
    retry "iptables --policy FORWARD ACCEPT &&
    echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf &&
    echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf &&
    sysctl -p" || exit 1
    echo "网络转发已配置。"
    mark_as_run "setup_forwarding"
fi
step=$((step + 1))

# 设置BBR加速
if has_run "setup_bbr"; then
    echo "步骤[$step]: BBR加速已设置，跳过。"
else
    progress $step $total_steps "正在设置BBR加速..."
    retry "uname -r &&
    echo 'net.core.default_qdisc=fq' | tee -a /etc/sysctl.conf &&
    echo 'net.ipv4.tcp_congestion_control=bbr' | tee -a /etc/sysctl.conf &&
    sysctl -p" || exit 1
    echo "BBR加速已启用。"
    mark_as_run "setup_bbr"
fi
step=$((step + 1))

# 设置国内更新源
if has_run "setup_sources"; then
    echo "步骤[$step]: 国内更新源已设置，跳过。"
else
    progress $step $total_steps "正在设置国内更新源..."
    retry "mv /etc/apt/sources.list /etc/apt/sources.list.bak &&
    tee /etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
EOF" || exit 1
    echo "国内更新源已配置。"
    mark_as_run "setup_sources"
fi
step=$((step + 1))

# 系统更新
if has_run "system_update"; then
    echo "步骤[$step]: 系统已更新，跳过。"
else
    progress $step $total_steps "正在更新系统..."
    retry "apt update && apt upgrade -y" || exit 1
    echo "系统更新已完成。"
    mark_as_run "system_update"
fi
