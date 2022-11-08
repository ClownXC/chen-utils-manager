#!/bin/bash


# function get_all_components
# function get_deploy_modules
# function get_all_component_of_module
# function get_component_config



# Define Variables
# HOME_DIR="/root/learning/shell/chen-utils-manager"
HOME_DIR=$1
CONFIG_FILE="spark/deploy.ini"
COMMON_INSTALL_FILE="common_install.sh"
COMMON_PATH="${HOME_DIR}/common"
TOOL_INSTALL_FILE="tools_install.sh"
TOOL_PATH="${HOME_DIR}/tool"

RED="\e[31m"
COLOR_END="\e[0m"
THIS_PID=$$

MODULE_NAME="modules"
TOOL="tool"
COMMON="common"
SPARK="spark"
USER="root"


# Func: get deploy modules in deploy.ini
function get_deploy_modules
{
    MODULES_LIST=$(sed -n '/\[modules\]/,/\[.*\]/p' ${HOME_DIR}/${CONFIG_FILE} | egrep -v "(^$|\[.*\]|^;|^#)")
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

function get_all_components
{
    for module in $(get_deploy_modules); do 
        COMPONENT_LIST=$(sed -n "/\[${module}\]/,/\[.*\]/p" ${HOME_DIR}/${CONFIG_FILE} | egrep -v "(^$|\[.*\])")
        echo "${COMPONENT_LIST}"
    done

}

function get_component_pid_by_name
{
    if [ $# -ne 1 ]; then
        return 1
    else
        # pids=$(ps -ef | grep $1 | grep -v grep | grep -v ${THIS_PID} |awk '{print $2}')
        pids=$(ps -ef | grep $1 | grep -v grep | grep -v $0 |awk '{print $2}')
        echo "${pids}"
    fi

}


function get_component_info_by_pid
{
    if [ $(ps -ef | awk -v pid=$1 '$2==pid {print}' | wc -l ) -eq 1 ]; then
        component_status="RUNNING"
    else
        component_status="STOPED"
    fi
    component_cpu=$(ps -ef | awk -v pid=$1 '$2==pid {print $3}')
    component_mem=$(ps -ef | awk -v pid=$1 '$2==pid {print $4}')
    component_start_time=$(ps -p $1 -o lstart | grep -v STARTED)
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
        components=$(sed -n "/\[$1\]/,/\[.*\]/p" ${HOME_DIR}/${CONFIG_FILE} | egrep -v "(^$|^#|\[.*\])")
        # components_format=(`echo ${components} | tr ',' ' '`)
        # echo ${components_format[@]}
        echo ${components}
    else
        echo "GroupName $1 is not in deploy.ini"
    fi
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

function get_component_nodes 
{
    nodes=(`echo $1 | tr ',' ' '`)
    [[ ${nodes[@]/master/} != ${nodes[@]} ]]
    if [ $? -eq 0 ]; then
        nodes=(${MASTER_NODE_LIST[@]} ${nodes[@]/master/})                
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


function xcall
{
    nodes=$1
    shift
    local user=$1
    shift
    commands=$@

    for node in ${nodes}; do
        echo "======${user} ${node} ${commands}===="
        ssh ${user}@${node} ${commands}
    done
}


function remote_call
{
    xcall $1 $2 $3
}

function wget_process 
{
    wget_node=$1
    xcall "${wget_node}" $2 "cp -v /usr/share/locale/zh_CN/LC_MESSAGES/wget.mo /usr/share/locale/zh_CN/LC_MESSAGES/wget.mo.bak20140827"
    xcall "${wget_node}" $2 "msgunfmt /usr/share/locale/zh_CN/LC_MESSAGES/wget.mo -o - | sed 's/eta(英国中部时间)/ETA/' | msgfmt - -o /tmp/zh_CN.mo"
    xcall "${wget_node}" $2 "cp -f -v /tmp/zh_CN.mo /usr/share/locale/zh_CN/LC_MESSAGES/wget.mo"   


}


###### main ######

echo "脚本安装路径: ${HOME_DIR}"

if [ ! -e ${HOME_DIR}/${CONFIG_FILE} ]; then
    echo -e "${RED} Error: ${CONFIG_FILE} is not exist, Please Check......${COLOR_END}"
    exit 1
fi
get_deploy_nodes
# wget_process "${WORKER_NODE_LIST}" ${USER}



#----------------------------------------------------------Common----------------------------------------------------------
is_module_in_config ${COMMON}
if [ $? -eq 0 ]; then
    if [ ! -e ${COMMON_PATH}/${COMMON_INSTALL_FILE} ]; then
        echo -e "${RED} Error: ${CONFIG_FILE} is not exist, Please Check......${COLOR_END}"
        exit 1
    fi
    sh ${COMMON_PATH}/${COMMON_INSTALL_FILE} ${HOME_DIR}
fi


#----------------------------------------------------------Tool----------------------------------------------------------

is_module_in_config ${TOOL}
if [ $? -eq 0 ]; then
    if [ ! -e ${TOOL_PATH}/${TOOL_INSTALL_FILE} ]; then
        echo -e "${RED} Error: ${CONFIG_FILE} is not exist, Please Check......${COLOR_END}"
        exit 1
    fi
    sh ${TOOL_PATH}/${TOOL_INSTALL_FILE} ${HOME_DIR}
fi



#----------------------------------------------------------Spark----------------------------------------------------------

is_module_in_config ${SPARK}
if [ $? -eq 0 ]; then
    echo "install spark..."
    declare -A spark_properties_map=$(get_properties_of_component ${SPARK})
    spark_master_nodes=$(get_component_nodes ${spark_properties_map["master"]})
    echo "spark master: ${spark_master_nodes}"
    spark_worker_nodes=$(get_component_nodes ${spark_properties_map["worker"]})
    echo "spark worker: ${spark_worker_nodes}"
    pkg_path=${spark_properties_map["pkg_path"]}
    echo "pkg_path: ${pkg_path}"
    spark_home=${spark_properties_map["spark_home"]}
    echo "spark_home: ${spark_home}"
    
    spark_version=${spark_properties_map["spark_version"]}
    hadoop_version=${spark_properties_map["hadoop_version"]}
    spark_nodes=(${spark_worker_nodes} ${spark_master_nodes})
    declare -A java_properties_map=$(get_properties_of_component java)  
    is_module_in_config ${COMMON}
    spark_java_home=${spark_properties_map["java_home"]}


    spark_install_mode=${spark_properties_map["install_mode"]}
    spark_hadoop_version=spark-${spark_version}-bin-${hadoop_version}
    echo "spark install mode: ${spark_install_mode}"

    for spark_node in ${spark_nodes[@]}; do
        echo "install node===: ${spark_node}"
        remote_call ${spark_node} ${USER} "[[ ! -d ${spark_home} ]] && mkdir -p ${spark_home} "
        if [ "${spark_install_mode}" == "local" ]; then
            scp ${pkg_path}/${spark_hadoop_version}.tgz ${USER}@${spark_node}:${spark_home}
        elif [ "${spark_install_mode}" == "remote" ]; then
            remote_call ${spark_node} ${USER} "[[ -f \"${spark_home}/${spark_hadoop_version}.tgz\" ]] && rm -f ${spark_home}/${spark_hadoop_version}.tgz "
            echo "node: ${spark_node} 正在下载: ${spark_hadoop_version}.tgz, waiting..."
            remote_call ${spark_node} ${USER} "wget -P ${spark_home} https://note3.oss-cn-hangzhou.aliyuncs.com/${spark_hadoop_version}.tgz -q"
        fi

        remote_call ${spark_node} ${USER} "tar -zxf ${spark_home}/${spark_hadoop_version}.tgz -C ${spark_home} "
        remote_call ${spark_node} ${USER} "cp ${spark_home}/${spark_hadoop_version}/conf/workers.template ${spark_home}/${spark_hadoop_version}/conf/workers"
        remote_call ${spark_node} ${USER} "cp ${spark_home}/${spark_hadoop_version}/conf/spark-env.sh.template ${spark_home}/${spark_hadoop_version}/conf/spark-env.sh"
        # # 目前只支持一个 master
        for s_node in ${spark_nodes[@]}; do
            remote_call ${spark_node} ${USER} "sed -i '/^localhost/d' ${spark_home}/${spark_hadoop_version}/conf/workers; echo \$(cat /etc/hosts | grep ${s_node} | awk 'NR==1{print \$2}') >> ${spark_home}/${spark_hadoop_version}/conf/workers"
        done

        remote_call ${spark_node} ${USER} "echo SPARK_MASTER_HOST=\$(cat /etc/hosts | grep ${spark_master_nodes} | awk 'NR==1{print \$2}') >> ${spark_home}/${spark_hadoop_version}/conf/spark-env.sh"
        remote_call ${spark_node} ${USER} "echo export JAVA_HOME=${spark_java_home} >> ${spark_home}/${spark_hadoop_version}/conf/spark-env.sh"


        # 启动 spark
        # remote_call ${master_node} ${USER} "sh ${spark_home}/${spark_version}/sbin/start-all.sh"

        
    
        
    done | awk '!a[$0]++ {print}'




fi










