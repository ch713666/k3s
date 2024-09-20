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
step=$((step + 1))

# 安装 Tailscale
while true; do
    progress $step $total_steps "正在安装 Tailscale..."
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://mirrors.ysicing.net/tailscale/stable/debian bookworm main" | sudo tee /etc/apt/sources.list.d/tailscale.list
    sudo apt-get update
    if sudo apt-get install -y tailscale; then
        echo "Tailscale 安装完成。"
        break
    else
        echo "Tailscale 安装失败，正在重试..."
        sleep 5  # 等待5秒后重试
    fi
done
step=$((step + 1))

# 安装 Docker
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
step=$((step + 1))

# Docker国内源配置
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
step=$((step + 1))

# 安装 k3s
progress $step $total_steps "正在安装 k3s..."
progress_bar 10  # 这里可以设置预估的安装时间（秒）

EXTERNAL_IP=$public_ip
NODE_IP=""
case "$(hostname)" in
    "hw-cn-master-01.3idp.com")
        NODE_IP="100.64.247.101"
        ;;
    "jd-cn-master-02.3idp.com")
        NODE_IP="100.64.247.102"
        ;;
    "hs-cn-master-03.3idp.com")
        NODE_IP="100.64.247.103"
        ;;
    *)
        echo "未识别的计算机名: $(hostname)，无法设置内部节点IP。"
        exit 1
        ;;
esac

DATASTORE_ENDPOINT="mysql://root:ZLjn78tglm@tcp(192.168.0.174:3306)/k3s"
VPN_AUTH="name=tailscale,joinKey=tskey-auth-k5MZBt4hmU11CNTRL-jRENRUyXJa5aUT1hCeEEa5peuQWBogMUQ"

curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
INSTALL_K3S_MIRROR=cn \
K3S_TOKEN=milkman247 \
INSTALL_K3S_SKIP_SELINUX_RPM=true \
sh -s server \
  --docker \
  --disable servicelb \
  --service-node-port-range=1-32767 \
  --write-kubeconfig-mode=644 \
  --write-kubeconfig ~/.kube/config \
  --node-ip "$NODE_IP" \
  --node-external-ip "$EXTERNAL_IP" \
  --flannel-external-ip \
  --node-label machine=huawei \
  --advertise-address "$EXTERNAL_IP" \
  --tls-san "$EXTERNAL_IP" \
  --tls-san k3s.3idp.com \
  --kube-proxy-arg proxy-mode=ipvs \
  --kube-proxy-arg ipvs-scheduler=lc \
  --kube-proxy-arg ipvs-min-sync-period=5s \
  --kube-proxy-arg ipvs-sync-period=30s \
  --kube-proxy-arg masquerade-all=true \
  --kube-proxy-arg metrics-bind-address=0.0.0.0 \
  --vpn-auth="$VPN_AUTH" \
  --datastore-endpoint="$DATASTORE_ENDPOINT"

# 安装完成提示
progress $step $total_steps "k3s 安装完成！"

