#!/bin/bash



function xcall
{
    nodes=$1
    local user=$2
    commands=$3

    for node in ${nodes}; do
        ssh ${user}@${node} ${commands}
        echo "======${user}: ${node} ${commands}===="
    done
}



if [ $# -lt 2 ];then
    echo "Usage: sh $0 username userpass"
    exit 1
fi

HOME_DIR=$1
COMMON_PATH="${HOME_DIR}/common"
shift
USER_NAME=$1
shift
USER_PASS=$1
shift
HOST_LIST=$@
echo "host: ${HOST_LIST}"


# echo 颜色
RED="\e[31m"
COLOR_END="\e[0m"
# 第一步：管理主机本地创建用户、设置密码
if [ $USER_NAME != "root" ]; then
    useradd ${USER_NAME}
    USER_HOME="/home/${USER_NAME}"
    echo ${USER_PASS} | passwd --stdin ${USER_NAME}
else
    USER_HOME="/root"
fi

echo "===${USER_HOME}==="

# 第二步：管理主机针对已创建的用产，生成密钥对
if ! command -v expect >/dev/null 2>&1; then
    echo "install expect..."
    yum -y install expect &> /dev/null
fi

[[ ! -f /root/.ssh/id_rsa ]] && ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa -q &>/dev/null
# 第三步：利用SSH非免密在所有需管理主机上创建用户、设置密码
if ! command -v sshpass >/dev/null 2>&1; then
    echo "sshpass not exists"
    yum -y install sshpass
    if [ $? -eq 0 ]; then
        echo "sshpass install success"
    else
        echo -e "${RED} sshpass install failure :( ${COLOR_END}"
        exit

    fi
fi





# 第四步：实现拷贝管理主机的公钥内容到对端主机
for host in ${HOST_LIST}
do
    echo "========= ssh node: ${host}: user: ${USER_NAME} pass: ${USER_PASS}========="
    expect <<EOF
      set timeout 10
      spawn ssh-copy-id -i /root/.ssh/id_rsa.pub ${USER_NAME}@${host}
      expect {
        "yes/no" { send "yes\n";exp_continue }
        "password" { send "${USER_PASS}\n" }
      }
      expect "password" { send "${USER_PASS}\n" }
EOF
done