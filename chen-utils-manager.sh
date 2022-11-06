#!/bin/bash

SHORTOPTS="h,f:,m:"
LONGOPTS="help,function:,module:"
ARGS=$(getopt --options $SHORTOPTS  --longoptions $LONGOPTS -- "$@" )
  
eval set -- "$ARGS"
SERVICE=""
while true;
do
    case $1 in
        -h|--help)
           echo "Print Help Information "
           shift
           ;;
        -f|--function)
            echo "function: $2"
            case $2 in
               install)  
                  echo '你选择了 [install]' 
                  
                  ;;
               monitor)  
                  echo '你选择了 [monitor]' 
                  ;;
               *)  
                  echo '现在还没有这个功能哦～' 
                  ;;
            esac
            shift 2
            ;;
        -m|--module)
            echo "module: $2"
            case $2 in
               spark)
                  echo '您选择了 spark'
                  install_path=$(pwd)
                  echo "install path: ${install_path}"
                  sh ${install_path}/spark/spark-deploy.sh ${install_path}
                  ;;
               flink)
                  echo '您选择了 flink'
                  ;;
               kafka)
                  echo 'kakfa'
                  ;;
               doris)
                  echo 'doris'
                  ;;
               clickhouse)
                  echo 'clickhouse'
                  ;;
               tool)
                  echo '您选择了 tool: tool 目前包括 oh-my-zsh, vim, lnav, ansible'
                  ;;
               common)
                  echo '您选择了 common: common 目前包括: java, scala, python, ssh免密'
                  ;;
               *)
                  echo '现在还不支持这个功能哦～'
                  ;;
            esac
            shift 2
            ;;
        --)
           shift
           break
           ;;
    esac
done