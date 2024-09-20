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

# 定义标记文件目录
CHECKPOINT_DIR="/var/tmp/k3s_install_checkpoints"
mkdir -p "$CHECKPOINT_DIR"

# 定义总步骤数
total_steps=1
step=1

# 获取公网IP地址
public_ip=$(curl -s ifconfig.me)

# k3s 安装步骤
install_k3s() {
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
    K3S_URL=https://100.64.247.101:6443 \
    K3S_TOKEN="K10bc8af7c026241957873558cfda178c8e9a4202ae8f54b849f84ac2e4d3306d8b::server:milkman247" \
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

    echo "k3s 安装完成！"
}

# 检查是否已执行过 k3s 安装
if [ ! -f "$CHECKPOINT_DIR/k3s_installed" ]; then
    install_k3s
    # 创建标记文件，记录 k3s 已安装
    touch "$CHECKPOINT_DIR/k3s_installed"
else
    echo "k3s 已安装，跳过安装步骤。"
fi
