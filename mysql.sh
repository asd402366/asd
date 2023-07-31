#!/bin/bash
#
#首先将压缩文件和配置文件(mysql57.cnf)放到/software目录
#软件目录：/usr/local/mysql
#数据目录：/data/mysql_data
#mysql-files目录：/data/mysql-files
#设置好root用户的密码
#deploy_mysql57.sh
#
#相关目录
MYSQL_FILE='/software'
MYSQL_HOME='/usr/local'
MYSQL_DATA='/data/mysql_data'
MYSQL_FILES='/data/mysql-files'
MYSQL_TAR='/software/mysql-5.7.35-linux-glibc2.12-x86_64.tar.gz'
MYSQL_UNZIP_FILE='mysql-5.7.35-linux-glibc2.12-x86_64'
TIME=`date +%Y%m%d%H%M%S`
  
#检查安装用户是否是root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install"
    exit 1
fi
  
#安装依赖包
rpm=`rpm -qa libaio|awk -F "-" '{print $1}'`
if [ -z "$rpm" ];then
    yum -y install libaio
else
    echo -e "\033[40;31m libaio [found]\033[40;37m"
fi
  
#防火墙开通3306端口
firewall-cmd --zone=public --add-port=3306/tcp --permanent
firewall-cmd --reload
 
#创建mysql用户
find / -name "mysql" -exec rm -rf {} \; >/dev/null 2>&1
id mysql
if [  "0" == "$?" ];then
    echo "mysql用户存在，删除mysql用户和组"
    pid=`pidof mysqld`
    kill -9  $pid >/dev/null 2>&1
    /usr/sbin/userdel -r  mysql > /dev/null 2>&1
    echo "1创建mysql用户和组" && sleep 2
    /usr/sbin/groupadd mysql
    /usr/sbin/useradd -s /sbin/nologin -g mysql mysql
else
    echo "2创建mysql用户和组" && sleep 2
    /usr/sbin/groupadd mysql
    /usr/sbin/useradd -s /sbin/nologin -g mysql mysql
fi
  
#配置文件限制
cat >>/etc/security/limits.conf<<EOF
* soft nproc 65535
* hard nproc 65535
* soft nofile 65535
* hard nofile 65535
EOF
echo "fs.file-max=65535" >> /etc/sysctl.conf
 
#安装程序
#安装前准备
echo "unzip starting......"
tar -zxf $MYSQL_TAR -C $MYSQL_HOME
#创建软链接
cd $MYSQL_HOME
ln -s $MYSQL_UNZIP_FILE mysql
#创建目录
echo "创建mysql相关文件目录" && sleep 2
mkdir -p $MYSQL_DATA $MYSQL_FILES
chown -R mysql:mysql $MYSQL_DATA $MYSQL_FILES
chmod -R 750 $MYSQL_DATA $MYSQL_FILES
#配置用户环境变量
echo "export PATH=/usr/local/mysql/bin:$PATH" >> /etc/profile
source /etc/profile
 
#配置文件(先备份后创建)
if [ -s /etc/my.cnf ]; then
    mv /etc/my.cnf /etc/my.cnf.$TIME.bak
fi
cat $MYSQL_FILE/mysql57.cnf > /etc/my.cnf
#初始化数据库
echo "initializing......"
mysqld --defaults-file=/etc/my.cnf --initialize --user=mysql
mysql_ssl_rsa_setup
  
#mysql服务设置，启动mysql
cd $MYSQL_HOME/mysql
#将启动脚本加入到系统服务，并设置为开机启动启动
cp -rf $MYSQL_HOME/mysql/support-files/mysql.server /etc/init.d/mysql.server
  
/sbin/chkconfig --add mysql.server
/sbin/chkconfig mysql.server on
/sbin/chkconfig --list
echo "mysql starting......"
service mysql.server start
#查看安装是否有报错
echo "=============================="
grep 'error' $MYSQL_DATA/error.log
#查看是否启动mysql
echo "=============================="
ps -ef|grep mysql
#查看root随机密码
echo "==============================password"
cd $MYSQL_DATA
a1=`grep 'A temporary password' error.log | awk -F"root@localhost: " '{ print $2}' `
#登录数据库
mysql -uroot -p${a1} --connect-expired-password <<EOF
set password = 'abcexxxxx';
create user 'root'@'%' identified by 'abcexxxxx';
grant all privileges on *.* to 'root'@'%' with grant option;
flush privileges;
exit
EOF
#重启mysql
sleep 1
systemctl restart mysql.server
echo "==============================install success"
#END
  
#对应的参数配置都写在配置文件中mysql57.cnf