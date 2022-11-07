#!/usr/bin/expect

ZSH_RES_HOME="/root/zsh"
USER_HOME="/root"


TIME_OUT=30




if ! command -v git >/dev/null 2>&1; then
    echo "install git..."
    yum -y install git &> /dev/null
fi

if ! command -v zsh >/dev/null 2>&1; then
    echo "install zsh..."
    yum install -y zsh &> /dev/null
fi

echo "开始下载 zsh 安装脚本，请稍等～～～"
[[ ! -d ${ZSH_RES_HOME} ]] && mkdir -p ${ZSH_RES_HOME} > /dev/null
wget -P ${ZSH_RES_HOME} https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -T 3 -t 3 -q -O - 
# if [ ! -e ${ZSH_RES_HOME}/install.sh ]; then
if [ $? -ne 0 ]; then
    echo "Github 连接失败"
    echo "改换国内的镜像源"
    if [ ! -f ${ZSH_RES_HOME}/install.sh ];then
        wget -P ${ZSH_RES_HOME} https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh -q
    fi
fi


# 编辑 install.sh
# REPO=${REPO:-ohmyzsh/ohmyzsh}
# REMOTE=${REMOTE:-https://github.com/${REPO}.git}
# 替换为
# REPO=${REPO:-mirrors/oh-my-zsh}
# REMOTE=${REMOTE:-https://gitee.com/${REPO}.git}
sed -i 's/REPO=${REPO:-ohmyzsh\/ohmyzsh}/REPO=${REPO:-mirrors\/oh-my-zsh}/g' ${ZSH_RES_HOME}/install.sh
sed -i 's/REMOTE=${REMOTE:-https:\/\/github.com\/${REPO}.git}/REMOTE=${REMOTE:-https:\/\/gitee.com\/${REPO}.git}/g' ${ZSH_RES_HOME}/install.sh
# 修改仓库地址
# cd ~/.oh-my-zsh
# git remote set-url origin https://gitee.com/mirrors/oh-my-zsh.git
# git pull

if ! command -v expect >/dev/null 2>&1; then
    echo "install expect..."
    yum -y install expect &> /dev/null
fi

# spawn sh install.sh &> /dev/null
# expect {
#     "[Y/n]" {send "Y\n"}
# }
# expect eof
sh ${ZSH_RES_HOME}/install.sh > /dev/null


if [ $? -eq 0 ]; then
    echo "oh-my-zsh 下载结束"
    echo "====================开始安装插件===================="
else 
    echo "oh-my-zsh 下载失败"
    exit
fi
echo "zsh-autosuggestions:"
git clone https://gitee.com/pocmon/zsh-autosuggestions.git ${USER_HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions
if [ $? -eq 0 ]; then
    echo "zsh-autosuggestions 成功"
fi
git clone https://gitee.com/gxkgle/zsh-syntax-highlighting.git ${USER_HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
if [ $? -eq 0 ]; then
    echo "zsh-autosuggestions 成功"
fi
sed -i 's/plugins=(git)/plugins=(sublime z history-substring-search git zsh-autosuggestions zsh-syntax-highlighting)/' ${USER_HOME}/.zshrc
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="ys"/' ${USER_HOME}/.zshrc
source ${USER_HOME}/.zshrc