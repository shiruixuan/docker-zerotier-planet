#!/bin/bash

CONTAINER_NAME="myztplanet"
ZEROTIER_PATH="$(pwd)/data/zerotier"
CONFIG_PATH="${ZEROTIER_PATH}/config"
DIST_PATH="${ZEROTIER_PATH}/dist"
ZTNCUI_PATH="${ZEROTIER_PATH}/ztncui"
DOCKER_IMAGE="shiruixuan/zerotier-planet:latest"

print_message() {
    local message=$1
    local color_code=$2
    echo -e "\033[${color_code}m${message}\033[0m"
}

# 检查内核版本
kernel_check() {
    os_name=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
    kernel_version=$(uname -r | cut -d'.' -f1)
    if ((kernel_version < 5)); then
        if [[ "$os_name" == "centos" ]]; then
            print_message "内核版本太低,请在菜单中选择CentOS内核升级" "31"
        else
            print_message "请自行升级系统内核到5.*及其以上版本" "31"
        fi
        exit 1
    else
        print_message "系统和内核版本检查通过，当前内核版本为：$kernel_version" "32"
    fi
}

# 安装lsof工具
install_lsof() {
    if ! command -v lsof &>/dev/null; then
        echo "开始安装lsof工具..."
        if command -v apt &>/dev/null; then
            apt update && apt install -y lsof
        elif command -v yum &>/dev/null; then
            yum install -y lsof
        fi
    fi
}

# 获取IP地址
configure_ip() {
    ipv4=$(curl -s https://ipv4.icanhazip.com/)
    ipv6=$(curl -s https://ipv6.icanhazip.com/)
    echo "获取到的IPv4地址为: $ipv4"
    echo "获取到的IPv6地址为: $ipv6"
}

# 安装zerotier-planet
kernel_check

echo "开始安装，如果你已经安装了，将会删除旧的数据，10秒后开始安装..."
sleep 10

install_lsof

docker rm -f ${CONTAINER_NAME} || true
rm -rf ${ZEROTIER_PATH}

ZT_PORT=9994
API_PORT=3443
FILE_PORT=3000

configure_ip

echo "---------------------------"
echo "使用的端口号为：${ZT_PORT}"
echo "API端口号为：${API_PORT}"
echo "FILE端口号为：${FILE_PORT}"
echo "IPv4地址为：${ipv4}"
echo "IPv6地址为：${ipv6}"
echo "---------------------------"

docker run -d \
	--name ${CONTAINER_NAME} \
	-p ${ZT_PORT}:${ZT_PORT} \
	-p ${ZT_PORT}:${ZT_PORT}/udp \
	-p ${API_PORT}:${API_PORT} \
	-p ${FILE_PORT}:${FILE_PORT} \
	-e IP_ADDR4=${ipv4} \
	-e IP_ADDR6=${ipv6} \
	-e ZT_PORT=${ZT_PORT} \
	-e API_PORT=${API_PORT} \
	-e FILE_SERVER_PORT=${FILE_PORT} \
	-v ${DIST_PATH}:/app/dist \
	-v ${ZTNCUI_PATH}:/app/ztncui \
	-v ${ZEROTIER_PATH}/one:/var/lib/zerotier-one \
	-v ${CONFIG_PATH}:/app/config \
	--restart unless-stopped \
	${DOCKER_IMAGE}

sleep 10

KEY=$(docker exec -it ${CONTAINER_NAME} sh -c 'cat /app/config/file_server.key' | tr -d '\r')
MOON_NAME=$(docker exec -it ${CONTAINER_NAME} sh -c 'ls /app/dist | grep moon' | tr -d '\r')

echo "安装完成"
echo "---------------------------"
echo "请访问 http://${ipv4}:${API_PORT} 进行配置"
echo "默认用户名：admin"
echo "默认密码：password"
echo "请及时修改密码"
echo "---------------------------"
echo "moon配置和planet配置在 ${DIST_PATH} 目录下"
echo "moons 文件下载： http://${ipv4}:${FILE_PORT}/${MOON_NAME}?key=${KEY} "
echo "planet文件下载： http://${ipv4}:${FILE_PORT}/planet?key=${KEY} "
echo "---------------------------"
echo "请放行以下端口：${ZT_PORT}/tcp,${ZT_PORT}/udp，${API_PORT}/tcp，${FILE_PORT}/tcp"
echo "---------------------------"
