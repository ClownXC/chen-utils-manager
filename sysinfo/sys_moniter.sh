#!/bin/bash

#show system information
PS3="Yource choice is: "

os_check()
{
	if [ -e /etc/redhat-release ];then
		REDHAT=`cat /etc/redhat-release| cut -d' ' -f1`//一般用awk
	else
		DEBIAN=`cat /etc/issue|cut -d' ' -f1`
	fi
	
	if [ "$REDHAT" == "CentOS" -o "$REDHAT" == "Red" ];then
		P_M=yum
	elif [ "$DEBIAN" == "Ubuntu" -o "DEBIAN" == "ubuntu"];then
		P_M=apt-get
	else
		OS not support
		exit 1
	fi
}
## $LOGNAME和$USER一样
if [ $LOGNAME != root];then
	echo "Please use root account"
	exit 1
fi

if ! which vmstat &>/dev/null; then
	echo "vmstat command not fount,now install"
	sleep 1
	os_check
	$P_M install procps -y
fi

which iostat &>/dev/null
if [ $? -ne 0 ];then
	echo "iostat command not fount,now install"
	sleep 1
	os_check
	$P_M install sysstat -y
fi

while true:
do
	select input in cpu_load disk_load disk_use disk_inode mem_use tcp_status cpu_top10 mem_yop10 traffic quit;
	do
		case $input in
		cpu_load)
			##CPU利用率与负载
			echo "--------------------------"
			i=1 
			while  [[ $i -le 3 ]];do
				echo -e "\003[32m 参考值${i}\033[0m"
				UTIL=`vmstat | awk '{if(NR==3) print 100-$15"%"}'`	##100-idle空闲的，NR==3处理第3行
				USER=`vmstat |awk '{if(NR==3) print $13"%"}'`
				SYS=`vmstat |awk '{if(NR==3) print $14"%"}'`
				IOWAIT=`vmstat |awk '{if(NR==3) print $16"%"}'`
				echo "Utile: $UTIL"
				echo "User user:$USER"
				echo "System use: $SYS"
				echo "I/O wait: $IOWAIT"
				let i++
				sleep 1
			done
			echo "--------------------------"
			break		##break是为了跳出select，重新显示菜单
			;;
		disk_load)
			#硬盘I/O负载
			echo "--------------------------"
			i=1
			while [[ $i -le 3 ]];do
				echo -e "\003[32m 参考值${i}\033[0m"
				UTIL=`iostat -x -k | awk '/^[v|s]/{OFS=": ";print $1,$NF"%"}'` ##OFS=": "表示以:或者空格分割
				READ=`iostat -x -k | awk '/^[v|s]/{OFS=": ";print $1,$6"KB"}'`
				WRITE=`iostat -x -k | awk '/^[v|s]/{OFS=": ";print $1,$7"KB"}'`			
				IOWAIT=`vmstat |awk '{if(NR==3) print $16"%"}}'`
				echo -e "Util:"
				echo -e "${UTIL}"
				echo "I/O wait: $IOWAIT"
				echo -e "I/O Wait: $IOWAIT"
				echo -e "Read/s: \n$READ"
				echo -e "Write/s: \n$WRITE"
				i=$(($i+1))
				sleep 1
			done
			echo "--------------------------"
			break		##break是为了跳出select，重新显示菜单
			;;
		disk_use)
			#硬盘利用率
			DISK_LOG=/tmp/disk_use.tmp			##&& 逻辑与
			DISK_TOTAL=`fdisk -l |awk '/^Disk.*bytes/ && /\/dev/{printf $2" ";printf "%d", $3;print "GB"}'`
			USE_RATE=`df -h | awk '/^\/dev/{print int($5)}'`		##awk内置函数:int
			for i in $USE_RATE;do
				if [ $i -gt 90 ];then
					PART=`df -h|awk '{if(int($5) === '''$i''') print $6}'`  ###'''$i'''：在单引号内部使用外部变量i
					echo "$PART = ${i}% >> $DISK_LOG"
				fi
			done
			echo "--------------------------"
			echo -e "Dick toltal:\n${DISK_TOTAL}"
			if [ -f $DISK_LOG ];then
				echo "--------------------------"
				cat $DISK_LOG
				echo "--------------------------"
				rm -f $DISK_LOG
			else
				echo "--------------------------"
				echo "Disk use rate no than 90% of the partition"
				echo "--------------------------"
			fi
			break
			;;
		disk_inode)
			#硬盘inode利用率
			INODE_LOG=/tmp/inode_use.tmp
			INODE_USE=`df -i | awk '/^\dev/{print int($5)}'`
			for i in $INODE_USE;do
				if [ $i -gt 90 ];then
					PART=`df -h|awk '{if(int($5) == '''$i''') print $6}'`  ###'''$i'''：在单引号内部使用外部变量i
					echo "$PART = ${i}%" >> $INODE_LOG
				fi
			done 
			if [ -f $INODE_LOG ];then
				echo "--------------------------"
				cat $INODE_LOG
				echo "--------------------------"
				rm -f $INODE_LOG
			else
				echo "--------------------------"
				echo "Disk use rate no than 90% of the partition"
				echo "--------------------------"
			fi
			break
			;;
		mem_use)
			##内存利用率
			echo "--------------------------"
			MEM_TOTAL=`free -m|awk '{if(NR==2)printf "%.1f" ,$2/1024} END{print "G"}'`  ##%.1保留小数点1位，f是浮点型
			USE=`free -m|awk '{if(NR==2)printf "%.1f" ,$3/1024} END{print "G"}'`
			FREE=`free -m|awk '{if(NR==2)printf "%.1f" ,$4/1024} END{print "G"}'`
			CACHE=`free -m|awk '{if(NR==2)printf "%.1f" ,$6/1024} END{print "G"}'`
			echo -e "Total: $MEM_TOTAL"
			echo -e "Use：$USE"
			echo -e "Free : $FREE"
			echo -e "Cache: $CACHE"
			echo "--------------------------"
			break
			;;
		tcp_status)
			##网络连接状态
			echo "--------------------------"
			COUNT=`ss -ant|awk '!/State/{status[$1]++}END{for(i in status) print i,status[i]}'`
			echo -e "TCP connection status:\n$COUNT"
			echo "--------------------------"
			;;
		cpu_top10)
			##占用CPU高的前10个进程
			echo "--------------------------"
			CPU_LOG=/tmp/cpu_top.tmp
			i=1
			while [[ $i -le 3 ]];do
				##printf不带换行符，print会有换行符
				##sort -k2按照第2列排序 -nr表示逆序
				ps aux|awk '{if(($3>0.1)){{printf "PID:" $2  "CPU: " $3 "%--->"}for(i=11;i<=NF;i++)if((i==NF))printf $i"\n";else printf $i}}'|sort -k4 -nr|head -10 >$CPU_LOG
				##循环从11列(进程名)开始打印，如果i等于最后一行，就打印i的列并换行，否则就打印i的列
				##if((i==NF))printf $i"\n";else printf $i也可以写成：if((i==NF))printf{$i"\n"};else {printf $i'
				if [[ -n `cat $CPU_LOG` ]];then		##-n：字符串长度不是0的话
					echo -e "\003[32m 参考值${i}\033[0m"
					cat $CPU_LOG
					>$CPU_LOG ##将文件清空
				else
					echo "No process using the CPU"
					break 
				fi
				let i++
				sleep 1
			done
			echo "--------------------------"
			break
			;;
		mem_top10)
		#占用内存高的前10个进程
			echo "--------------------------"
			MEM_LOG=/tmp/mem_top.tmp
			i=1
			while [[ $i -le 3 ]];do
				##printf不带换行符，print会有换行符
				##sort -k2按照第2列排序 -nr表示逆序
				ps aux|awk '{if(($3>0.1)){{printf "PID:" $2  "MEM: " $4 "%--->"}for(i=11;i<=NF;i++)if((i==NF))printf $i"\n";else printf $i}}'|sort -k4 -nr|head -10 >$CPU_LOG
				if [[ -n `cat $MEM_LOG` ]];then		##-n：字符串长度不是0的话
					echo -e "\003[32m 参考值${i}\033[0m"
					cat $MEM_LOG
					>$MEM_LOG ##将文件清空
				else
					echo "No process using the Memory"
					break 
				fi
				let i++
				sleep 1
			done
			echo "--------------------------"
			break
			;;
		traffic)
			#查看网络流量
			while true;do
				read -p "Please enter the network card name(eth[0-9]) or em[0-9]: " eth
				if [ `ifoconfig`| grep -c "\<$eth\>" -eq 1 ];then
					break
				else
					echo "Input format error or Do not have the card name,please input again"	
				fi
				echo "--------------------------"
				echo -e "In ------- Out"
				i=1
				while [[ $i -le 3 ]];do			##循环输出三次
					##Centos6的RX与TX行号等于8
					##Centos7的RX行号为5，TX行号等于7,,
					OLS_IN=`ifconfig $eth |awk -F'[: ]+' '{/bytes/if(NR==8) print $4;else if(NR==5)print $6}'`  ##-F'[: ]+':表示一个或多个空格
					OLS_OUT=`ifconfig $eth |awk -F'[: ]+' '{/bytes/if(NR==8) print $9;else if(NR==7)print $6}'`
					sleep 1
					NEW_IN=`ifconfig $eth |awk -F'[: ]+' '{/bytes/if(NR==8) print $4;else if(NR==5)print $6}'`
					NEW_OUT=`ifconfig $eth |awk -F'[: ]+' '{/bytes/if(NR==8) print $9;else if(NR==7)print $6}'`
	
					IN=`awk 'BEGIN{printf "%.1f\n",'$((${NEW_IN}-${OLD_IN}))'/1024/128}'`##最后得到的单位是Mbit
					OUT=`awk 'BEGIN{printf "%.1f\n",'$((${NEW_OUT}-${OLD_OUT}))'/1024/128}'`
					echo "${IN}MB/s ${OUT}MB/s"
	
					i=$(($i+1))
					sleep 1
			done
			echo "--------------------------"
			break
			;;
		quit)
			exit 0
			;;
		*)
			echo "--------------------------"
			echo "Please enter the number"
			echo "--------------------------"
			break
			;;
		esac	
	done
done


