 
PS3='Please enter your choice: '
options=("install" "monitor" "search" "Quit")
echo 'welcome utils-manager'
select opt in "${options[@]}"
do
    case $opt in
        "install")
            echo "请从列表中选择您需要安装的软件～"
            install_options=("flink" "spark" "hadoop" "kylin" "doris" "hudi" "iceberg" "mysql" "kafka" "docker" "common" "tool" "quit")
            select install_opt in "${install_options[@]}"
            do
               case $install_opt in
                  "flink")
                     echo "已下载 flink 安装脚本, 请执行 ./flink-install -h 按照提示安装"
                     ;;
                  "spark")
                     install_path=$(pwd)
                     echo "install path: ${install_path}"
                     sh ${install_path}/spark/spark-deploy.sh ${install_path}
                     ;;
                  "hadoop")
                     echo "已下载 hadoop 安装脚本, 请执行 ./hadoop-install -h 按照提示安装"
                     ;;
                  "kylin")
                     echo "已下载 kylin 安装脚本, 请执行 ./kylin-install -h 按照提示安装"
                     ;;
                  "doris")
                     echo "已下载 doris 安装脚本, 请执行 ./doris-install -h 按照提示安装"
                     ;;
                  "hudi")
                     echo "已下载 hudi 安装脚本, 请执行 ./hudi-install -h 按照提示安装"
                     ;;
                  "iceberg")
                     echo "已下载 iceberg 安装脚本, 请执行 ./iceberg-install -h 按照提示安装"
                     ;;
                  "mysql")
                     echo "已下载 mysql 安装脚本, 请执行 ./mysql-install -h 按照提示安装"
                     ;;
                  "kafka")
                     echo "已下载 kafka 安装脚本, 请执行 ./kafka-install -h 按照提示安装"
                     ;;
                  "docker")
                     echo "已下载 docker 安装脚本, 请执行 ./docker-install -h 按照提示安装"
                     ;;
                  "common")
                     touch ./common-install.sh
                     if [ $? -eq 0 ]; then
                         echo "已下载 common(java, scala, python, ssh免密) 安装脚本, 请执行 ./common-install -h 按照提示安装"
                     else
                        echo "failed"
                     fi
                     ;;
                  "tool")
                     chmod +x ./tools-install.sh
                     echo "已下载 tool(oh-my-zsh, vim, ansible, lnav) 安装脚本, 请执行 ./tools-install -h 按照提示安装"
                     ;;
                  "quit")
                     exit
                     ;;
                  *) echo invalid option;;
                  
               esac
            done
            ;;
        "monitor")
            echo "you chose choice 2"
            ;;
        "search")
            echo "you chose choice 3"
            ;;
        "Quit")
            break
            ;;
        *) echo invalid option;;
    esac
done