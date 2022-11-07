#!/bin/bash

# cd ./tool
# file="zsh_install.sh"
# if [ ! -f "$file" ]; then 
#     echo "file not exist"
# else
#     echo "file exist"
# fi

HOME_DIR=$1
CONFIG_FILE="spark/deploy.ini"
RED="\e[31m"
COLOR_END="\e[0m"
THIS_PID=$$
TOOL="tool"
COMMON="common"
TOOL_PATH="${HOME_DIR}/tool"
COMMON_PATH="${HOME_DIR}/common"
ZSH_INSTALL_FILE="zsh_install.sh"
USER="root"
ZSH_RES_HOME="/root"


# Func: get deploy modules in deploy.ini
function get_deploy_modules
{
    MODULES_LIST=$(sed -n '/\[modules\]/,/\[.*\]/p' ${HOME_DIR}/${CONFIG_FILE} | egrep -v "(^$|\[.*\])")
    echo "${MODULES_LIST}"
}

function get_deploy_nodes
{
    NODE_LIST=$(sed -n '/\[node\]/,/\[.*\]/p' ${HOME_DIR}/${CONFIG_FILE} | egrep -v "(^$|\[.*\])")
    for node_define in ${NODE_LIST}; do
        arr=($(echo ${node_define} | awk 'BEGIN{FS="=";OFS=" "} {print $1,$2}'))
        node_desc=${arr[0]}
        nodes=(`echo ${arr[1]} | tr ',' ' '`) 
        if [ ${node_desc} == "all" ]; then
            ALL_NODE_LIST=${nodes[@]}
        elif [ ${node_desc} == "master" ]; then
            MASTER_NODE_LIST=${nodes[@]}
        elif [ ${node_desc} == "worker" ]; then
            WORKER_NODE_LIST=${nodes[@]}
        fi 
    done
    # echo "${NODE_LIST}"
}

function is_module_in_config
{
    for module in $(get_deploy_modules); do
        if [ ${module} == $1 ]; then
            return
        fi
    done
    return 1
}


function get_all_component_of_module
{
    is_module_in_config $1
    if [ $? -eq 0 ]; then
        components=$(sed -n "/\[$1\]/,/\[.*\]/p" ${HOME_DIR}/${CONFIG_FILE} | egrep -v "(^$|^#|\[.*\]|^;)")
        echo ${components}
    else
        echo "GroupName $1 is not in deploy.ini"
    fi
}

function is_compponent_in_module
{
    for component in $(get_all_component_of_module $1); do
        if [ ${component} == $2 ]; then
            return
        fi
    done
    return 1
}



function get_properties_of_component
{
    PROPERTIES=$(sed -n "/\[$1\]/,/\[.*\]/p" ${HOME_DIR}/${CONFIG_FILE} | egrep -v "(^$|\[.*\]|^;|^#)")
    for property in ${PROPERTIES}; do
        # arr=($(echo ${property} | awk 'BEGIN{FS="=";OFS=" "} {print $1,$2}'))
        arr=($(echo ${property} | tr '=' ' '))
        prop_name=${arr[0]}
        prop_val=`echo ${arr[1]}`
        map="$map [${prop_name}]=${prop_val}"
    done
    echo "(${map})"
}

function xcall
{
    nodes=$1
    shift
    local user=$1
    shift
    commands=$@

    for node in ${nodes}; do
        ssh ${user}@${node} ${commands}
        echo "======${user} ${node} ${commands}===="
    done
}


function remote_call
{
    xcall $1 $2 $3
}



function get_component_nodes 
{
    nodes=(`echo $1 | tr ',' ' '`)
    [[ ${nodes[@]/master/} != ${nodes[@]} ]]
    if [ $? -eq 0 ]; then
        nodes=(${MASTER_NODE_LIST[@]} ${nodes[@]/master/} )                
    fi
    [[ ${nodes[@]/all/} != ${nodes[@]} ]]
    if [ $? -eq 0 ]; then
        nodes=(${ALL_NODE_LIST[@]} ${nodes[@]/all/})
    fi

    [[ ${nodes[@]/worker/} != ${nodes[@]} ]]
    if [ $? -eq 0 ]; then
        # 合并数组: master=master,172.17.16.229,172.17.16.230
        nodes=(${WORKER_NODE_LIST[@]} ${nodes[@]/worker/})
    fi
    echo ${nodes[@]}
}





get_deploy_nodes
is_module_in_config ${TOOL}
if [ $? -eq 0 ]; then
    components=$(get_all_component_of_module ${TOOL})
    # # # 目前需要首先配置 ssh 免密
    # $(is_compponent_in_module ${COMMON} "ssh")
    # if [ $? -eq 0 ]; then
    #     sh ${COMMON_PATH}/ssh/ssh_login.sh root 3494269
    # fi

    echo "-------------------开始安装 Tool 模块-------------------"
    for component in ${components}; do
        if [ ${component} == "vim" ]; then
            echo "install component: ${component}"
            declare -A vim_properties_map=$(get_properties_of_component vim)
            vim_nodes=$(get_component_nodes ${vim_properties_map["node"]})
            echo "vim nodes: ${vim_nodes}"
            xcall "${vim_nodes}" ${USER} "yum -y install vim"
        elif [ ${component} == "ansible" ]; then
            echo "install component: ${component}"
            declare -A ansible_properties_map=$(get_properties_of_component ansible)
            ansible_nodes=$(get_component_nodes ${ansible_properties_map["node"]})
            echo "ansible nodes: ${ansible_nodes}"
            xcall "${vim_nodes}" ${USER} "yum -y install ansible"
        elif [ ${component} == "oh-my-zsh" ]; then
            echo "install component: ${component}"
            declare -A omz_properties_map=$(get_properties_of_component oh-my-zsh)
            omz_nodes=$(get_component_nodes ${omz_properties_map["node"]})
            echo "oh-my-zsh nodes: ${omz_nodes}"
            for node in ${omz_nodes}; do
                scp ${TOOL_PATH}/zsh/${ZSH_INSTALL_FILE} ${USER}@${node}:${ZSH_RES_HOME}
                remote_call "${node}" ${USER} "sh ${ZSH_RES_HOME}/${ZSH_INSTALL_FILE}"
            done
        elif [ ${component} == "lnav" ]; then
            echo "install component: ${component}"
        elif [ ${component} == "trash" ]; then
            echo "install component: ${component}"
        fi

    done
    echo "----------------------------------Tool Install Success :)-------------------------------------"
fi