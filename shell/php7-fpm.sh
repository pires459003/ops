#!/bin/bash
# 文件名: php7-cgi.sh
# 作者: shuhui
# 版本: v1.1

### 更新日志 ###
# 2015-11-28 版本 v1.0: 以 7.0 为版本为基础，实现常用的 PHP-CGI 功能
# 2016-01-04 版本 v1.1: 更新 PHP版本为7.0.1，增加编译并行数量


### 变量定义区域 开始 ###

PREFIX=/usr/local                                  # 安装路径
PHP_VER=7.0.1                                      # PHP 版本号
CPU_NUM=$(grep processor /proc/cpuinfo|wc -l)      # CPU 核心数量[编译并行数量]

### 变量定义区域 结束 ###

# 安装php-7
function php7_install() {
	[[ -e php-${PHP_VER}.tar.bz2 ]] || wget -c https://down.vqiu.cn/package/tarball/php/php-${PHP_VER}.tar.bz2
	tar axvf php-${PHP_VER}.tar.bz2
	cd php-${PHP_VER}
	./configure \
	--prefix=${PREFIX}/php7 \
	--with-config-file-path=${PREFIX}/php7/etc \
	--enable-mysqlnd \
	--enable-fpm \
	--enable-static \
	--enable-inline-optimization \
	--enable-sockets \
	--enable-wddx \
	--enable-zip \
	--enable-calendar \
	--enable-bcmath \
	--enable-soap \
	--with-zlib \
	--with-iconv \
	--with-xmlrpc \
	--enable-mbstring \
	--without-sqlite3 \
	--without-pdo-sqlite \
	--with-curl \
	--enable-ftp \
	--with-mcrypt=${PREFIX}/libmcrypt \
	--with-gd=${PREFIX}/gd2 \
	--with-freetype-dir=${PREFIX}/freetype \
	--with-jpeg-dir=${PREFIX}/jpeg \
	--with-png-dir=${PREFIX}/libpng \
	--disable-ipv6 \
	--disable-debug \
	--with-openssl \
	--disable-maintainer-zts \
	--enable-opcache \
	--disable-fileinfo
	
	[[ ${CPU_NUM} -gt 1 ]] && make -j${CPU_NUM} || make
	make install
	
    if [[ $? -eq 0 ]]
    then
    	# 建立软链接
        ln -sv ${PREFIX}/php7 ${PREFIX}/php
        
        # 建立配置文件
        \cp php.ini-production ${PREFIX}/php/etc/php.ini		
		
        # \cp sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm		# 老版本启动方式
        # chmod +x /etc/init.d/php-fpm
        \cp ${PREFIX}/php/etc/php-fpm.conf.default ${PREFIX}/php/etc/php-fpm.conf
        \cp ${PREFIX}/php/etc/php-fpm.d/www.conf.default ${PREFIX}/php/etc/php-fpm.d/www.conf
		
		\cp sapi/fpm/php-fpm.service /usr/lib/systemd/system/
		sed -i "s:\${prefix}:${PREFIX}/php:" /usr/lib/systemd/system/php-fpm.service
		sed -i "s:\${exec_prefix}:${PREFIX}/php:" /usr/lib/systemd/system/php-fpm.service
		systemctl daemon-reload
		systemctl start php-fpm.service
		systemctl enable php-fpm.service

		
		
        # 修改 php.ini 参数
        for i in ${PREFIX}/php/etc/php.ini
        do
            sed -i 's#output_buffering = Off#output_buffering = On#' $i
            sed -i 's/post_max_size = 8M/post_max_size = 20M/g' $i
            sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 10M/g' $i
            sed -i 's/;date.timezone =/date.timezone = PRC/g' $i
            sed -i 's/short_open_tag = Off/short_open_tag = On/g' $i
            sed -i 's/; cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' $i
            sed -i 's/; cgi.fix_pathinfo=0/cgi.fix_pathinfo=0/g' $i
            sed -i 's/max_execution_time = 30/max_execution_time = 300/g' $i
            sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,scandir,chgrp,chown,shell_exec,proc_open,proc_get_status,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' $i
        done
        
        # 添加到系统环境变量
        echo "export PATH=\$PATH:${PREFIX}/php/bin">/etc/profile.d/php.sh
        source /etc/profile.d/php.sh
    fi
}

php7_install
