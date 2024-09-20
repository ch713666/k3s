#!/bin/bash

# 定义一个简单的进度函数
progress() {
    echo "[$1/$2] $3"
}

total_steps=2
step=1

# 定义标记文件路径
docker_installed_flag="/var/log/docker_installed.flag"
docker_configured_flag="/var/log/docker_configured.flag"

# 安装 Docker
if [ ! -f "$docker_installed_flag" ]; then
    progress $step $total_steps "正在安装 Docker..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc # 卸载老版本docker
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get install -y ca-certificates curl gnupg lsb-release  # 安装docker依赖
    curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add - # 添加docker密钥
    sudo add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" # 添加阿里云docker软件源
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io # 安装docker
    sudo docker version # 检查docker版本
    echo "Docker 安装完成。"
    
    # 创建标记文件
    sudo touch "$docker_installed_flag"
else
    echo "Docker 已经安装，跳过该步骤。"
fi
step=$((step + 1))

# Docker国内源配置
if [ ! -f "$docker_configured_flag" ]; then
    progress $step $total_steps "正在配置 Docker 国内源..."
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": [
        "https://docker.kejilion.pro"
    ]
}
EOF
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    echo "Docker 国内源配置完成。"
    
    # 创建标记文件
    sudo touch "$docker_configured_flag"
else
    echo "Docker 国内源已经配置，跳过该步骤。"
fi
