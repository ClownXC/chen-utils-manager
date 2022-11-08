#!/bin/bash


HOME_DIR=$1
CONFIG_FILE="spark/deploy.ini"
RED="\e[31m"
COLOR_END="\e[0m"
THIS_PID=$$
COMMON="common"
JAVA="java"
COMMON_PATH="${HOME_DIR}/common"
USER="root"
PROFILE_FILE="/etc/profile"


# Func: get deploy modules in deploy.ini
function get_deploy_modules
{
    MODULES_LIST=$(sed -n '/\[modules\]/,/\[.*\]/p' ${HOME_DIR}/${CONFIG_FILE} | egrep -v "(^$|\[.*\])")
    echo "${MODULES_LIST}"
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
        echo "======${user}: ${node} commands: ${commands}===="
        ssh ${user}@${node} ${commands}
    done
}


function remote_call
{
    xcall $1 $2 $3
}

function call
{
    pass=$1
    command=$2
    sshpass -p${ROOT_PASS} ${command}

}






function java_install
{
    declare -A java_properties_map=$(get_properties_of_component java)
    local java_nodes=$(get_component_nodes ${java_properties_map["node"]})
    echo "java nodes: ${java_nodes}"
    local mode=${java_properties_map["mode"]}
    local home=${java_properties_map["home"]}
    xcall "${java_nodes}" ${USER} "[[ ! -d  ${home} ]] && mkdir -p ${home}"
    if [ ${mode} == "local" ]; then
        local pkg_path=${java_properties_map["pkg_path"]}
        for node in ${java_nodes}; do
            scp ${pkg_path} ${USER}@${node}:${home}
        done 
    elif [ ${mode} == "remote" ]; then
        local remote_path=$(get_component_nodes ${java_properties_map["remote_path"]})
        xcall "${java_nodes}" ${USER} "wget ${remote_path} -P ${home} -q"
    fi
    xcall "${java_nodes}" ${USER} 'for open_jdk_pkg in `rpm -qa | egrep "^java-1.*.0-openjdk-"`;do echo ${open_jdk_pkg}; rpm -e --nodeps ${open_jdk_pkg}; done'
    xcall "${java_nodes}" ${USER} "tar -zxf ${home}/jdk-8u241-linux-x64.tar.gz -C ${home}/" > /dev/null
    J_HOME=${home}/jdk1.8.0_241
    if [ $? -eq 0 ]; then
        xcall "${java_nodes}" ${USER} "echo export JAVA_HOME=${J_HOME} >> ${PROFILE_FILE}"
        xcall "${java_nodes}" ${USER} "echo export CLASSPATH=.:${J_HOME}/jre/lib/rt.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar >> ${PROFILE_FILE}"
        # ssh root@${java_nodes} 'echo export PATH=\$PATH:/usr/local/java/bin >> /etc/profile'
        xcall "${java_nodes}" ${USER} "echo export PATH='\$PATH':${J_HOME}/bin >> ${PROFILE_FILE}"
        xcall "${java_nodes}" ${USER} ". ${PROFILE_FILE}"
    fi
}



function scala_install
{
    declare -A scala_properties_map=$(get_properties_of_component scala)
    local scala_nodes=$(get_component_nodes ${scala_properties_map["node"]})
    local remote_url=$(get_component_nodes ${scala_properties_map["remote_url"]})
    echo "scala nodes: ${scala_nodes}"
    local scala_version=${scala_properties_map["version"]}
    if [ "${scala_version}" == "2.12" ]; then
        scala_version="2.12.17"
        scala_pkg_path="${scala_properties_map["pkg_path"]}/scala-${scala_version}.tgz"
        
    elif [ "${scala_version}" == "2.11" ]; then
        scala_version="2.11.8"
        scala_pkg_path="${scala_properties_map["pkg_path"]}/scala-${scala_version}.tgz"
    fi
    local scala_mode=${scala_properties_map["mode"]}
    local scala_home=${scala_properties_map["home"]}
    xcall "${scala_nodes}" ${USER} "[[ ! -d ${scala_home} ]] && mkdir -p ${scala_home}"
    if [ "${scala_mode}" == "local" ]; then
        for node in ${scala_nodes}; do
            scp ${scala_pkg_path} ${USER}@${node}:${scala_home}
        done
    elif [ "${scala_mode}" == "remote" ]; then
        # xcall "${scala_nodes}" ${USER} "wget -P ${scala_home} https://downloads.lightbend.com/scala/${scala_version}/scala-${scala_version}.tgz"
        xcall "${scala_nodes}" ${USER} "wget -P ${scala_home} ${remote_url} -q"
    fi
    xcall "${scala_nodes}" ${USER} "tar -zxf ${scala_home}/scala-${scala_version}.tgz -C ${scala_home}/"
    S_HOME=${scala_home}/scala-${scala_version}
    if [ $? -eq 0 ]; then
        xcall "${scala_nodes}" ${USER} "echo export SCALA_HOME=${S_HOME} >> ${PROFILE_FILE}"
        xcall "${scala_nodes}" ${USER} "echo export PATH='\$PATH':/usr/local/opt/scala-${scala_version}/bin >> ${PROFILE_FILE}"
        xcall "${scala_nodes}" ${USER} "source ${PROFILE_FILE}"
    fi
}




get_deploy_nodes
is_module_in_config ${COMMON}
if [ $? -eq 0 ]; then
    echo "-------------------开始安装 common 模块-------------------"
    components=$(get_all_component_of_module ${COMMON})
    # 目前需要首先配置 ssh 免密
    $(is_compponent_in_module ${COMMON} "ssh")
    if [ $? -eq 0 ]; then

        declare -A ssh_properties_map=$(get_properties_of_component ssh)
        ssh_nodes=$(get_component_nodes ${ssh_properties_map["node"]})
        echo "ssh nodes: ${ssh_nodes}"
        root_password=$(get_component_nodes ${ssh_properties_map["root_password"]})
        echo "password: ${root_password}"
        ssh_user=$(get_component_nodes ${ssh_properties_map["ssh_user"]})
        echo "ssh user: ${ssh_user}"
        sh ${COMMON_PATH}/ssh/ssh_login.sh  "${HOME_DIR}" "${ssh_user}" "${root_password}" "${ssh_nodes}" > /dev/null
        echo "COMMON_PATH: ${COMMON_PATH}"

        for node in ${ssh_nodes}; do
            scp ${COMMON_PATH}/ssh/ssh_login.sh root@${node}:/root
            remote_call ${node} ${USER} "sh /root/ssh_login.sh ${HOME_DIR} ${ssh_user} ${root_password} \"${ssh_nodes}\"" > /dev/null
        done

    fi


    for component in ${components}; do
        if [ ${component} == "java" ]; then
            echo "install component: ${component}"
            java_install
        elif [ ${component} == "scala" ]; then
            echo "install component: ${component}"
            scala_install
        elif [ ${component} == "hosts" ]; then
            echo "config component: ${component}"
            declare -A hosts_properties_map=$(get_properties_of_component hosts)
            hosts_nodes=$(get_component_nodes ${hosts_properties_map["node"]})
            echo "hosts nodes: ${hosts_nodes}"
            for key in ${!hosts_properties_map[@]}; do
                if [ ${key} != "node" ]; then
                    hosts_val=${hosts_properties_map[${key}]}
                    if [ ${hosts_val} == "worker..." ]; then
                        workers=(${WORKER_NODE_LIST})
                        echo "size: ${#workers[@]}"
                        for((i=1; i<=${#workers[@]}; i++)); do
                            xcall "${hosts_nodes}" ${USER} "echo ${workers[i-1]} ${key}${i} >> /etc/hosts"
                        done
                    elif [ ${hosts_val} == "master..." ]; then
                        masters=(${MASTER_NODE_LIST})
                        echo "size: ${#masters[@]}"
                        for((i=1; i<=${#masters[@]}; i++)); do
                            xcall "${hosts_nodes}" ${USER} "echo ${masters[i-1]} ${key}${i} >> /etc/hosts"
                        done
                    elif [ ${hosts_val} == "master" ]; then
                        masters=(${MASTER_NODE_LIST})
                        echo "size: ${#masters[@]}"
                        for((i=1; i<=${#masters[@]}; i++)); do
                            xcall "${hosts_nodes}" ${USER} "echo ${masters[i-1]} ${key} >> /etc/hosts"
                        done
                    elif [ ${hosts_val} == "all..." ]; then
                        alls=(${ALL_NODE_LIST})
                        echo "size: ${#alls[@]}"
                        for((i=1; i<=${#alls[@]}; i++)); do
                            xcall "${hosts_nodes}" ${USER} "echo ${alls[i-1]} ${key}${i} >> /etc/hosts"
                        done

                    else
                        xcall "${hosts_nodes}" ${USER} "echo ${hosts_val} ${key} >> /etc/hosts"
                    fi
                    
                fi
            done
        elif [ ${component} == "hostname" ]; then
            echo "install component: ${component}"
            declare -A hostname_properties_map=$(get_properties_of_component hostname)
            for key in ${!hosts_properties_map[@]}; do
                if [ ${key} != "node" ]; then
                    hosts_val=${hosts_properties_map[${key}]}
                    if [ ${hosts_val} == "worker..." ]; then
                        workers=(${WORKER_NODE_LIST})
                        for ((i=1; i<=${#workers[@]}; i++)); do
                            remote_call ${workers[i-1]} ${USER} "hostnamectl set-hostname ${key}${i}"
                        done
                    elif [ ${hosts_val} == "master..." ]; then
                        masters=(${MASTER_NODE_LIST})
                        for ((i=1; i<=${#masters[@]}; i++)); do
                            remote_call ${masters[i-1]} ${USER} "hostnamectl set-hostname ${key}${i}"
                        done
                    elif [ ${hosts_val} == "all..." ]; then
                        alls=(${ALL_NODE_LIST})
                        for ((i=1; i<=${#alls[@]}; i++)); do
                            remote_call ${alls[i-1]} ${USER} "hostnamectl set-hostname ${key}${i}"
                        done
                    elif [ ${hosts_val} == "master" ]; then
                        masters=${MASTER_NODE_LIST}
                        echo "size: ${#masters[@]}"
                        remote_call "${masters}" ${USER} "hostnamectl set-hostname ${key}"
                    else
                        remote_call ${hosts_val} ${USER} "hostnamectl set-hostname ${key}"
                    fi
                    
                fi
            done            
        elif [ ${component} == "firewalld" ]; then
            echo "install component: ${component}"
            declare -A firewlld_properties_map=$(get_properties_of_component firewalld)
            firewlld_nodes=$(get_component_nodes ${firewlld_properties_map["node"]})
            echo "firewlld nodes: ${firewlld_nodes}"
            xcall "${firewlld_nodes}" ${USER} "systemctl stop firewalld.service"
            xcall "${firewlld_nodes}" ${USER} "systemctl disable firewalld.service"
        elif [ ${component} == "selinux" ]; then
            echo "install component: ${component}"
            declare -A selinux_properties_map=$(get_properties_of_component selinux)
            selinux_nodes=$(get_component_nodes ${selinux_properties_map["node"]})
            echo "selinux_nodes: ${selinux_nodes}"
            xcall "${selinux_nodes}" ${USER} "sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config"
            xcall "${selinux_nodes}" ${USER} "setenforce 0"
        fi

    done
fi











