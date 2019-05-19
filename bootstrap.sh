#!/bin/bash
# -- helper function to check: if [ $(contains "${services[@]}" "one") == "y" ]; then
# https://stackoverflow.com/questions/3685970/check-if-a-bash-array-contains-a-value
function contains() {
    local n=$#
    local value=${!n}
    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            echo "y"
            return 0
        fi
    }
    echo "n"
    return 1
}
services=()
while test $# -gt 0
do
	services+=("$1")
    shift
done


# -- ln -s etc folders from etc image before staring any installations
if [ $(contains "${services[@]}" "--apache2") == "y" ]; then
	echo "not yet implemented"
	# ln -s /media/etc/apache2 /etc/apache2
fi
if [ $(contains "${services[@]}" "--nginx") == "y" ]; then
	mkdir /etc/nginx
	ln -s /vagrant/provisioning/nginx/inc /etc/nginx/
	ln -s /vagrant/provisioning/nginx/sites-enabled /etc/nginx/
fi

apt-get -y update
DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" -y install tmux aptitude htop zsh curl vim apt-transport-https ca-certificates gnupg2 software-properties-common

# -- sendmail config -------------------------
#DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" -y install sendmail
#printf "y\ny\ny\n" > /tmp/dass
#sendmailconfig < /tmp/dass
# -- zsh config -------------------------------
echo "source /media/etc/.zshrc" > /home/vagrant/.zshrc
chsh -s `which zsh` vagrant
# -- add handy aliases
echo "alias l='ls -lah'" >> /home/vagrant/.bash_aliases
echo "alias s='sudo -u www-data HOME=/var/www'" >> /home/vagrant/.bash_aliases
# echo "alias webpack='tmux a -t webpack'" >> /home/vagrant/.bash_aliases
chown vagrant:vagrant /home/vagrant/.zshrc
chown vagrant:vagrant /home/vagrant/.bash_aliases
# chown vagrant:vagrant /home/vagrant/.bashrc

if [ $(contains "${services[@]}" "--node") == "y" ]; then
	curl -sL https://deb.nodesource.com/setup_9.x | bash -
	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" -y install nodejs
fi

if [ $(contains "${services[@]}" "--mysql") == "y" ]; then
	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" -y install mariadb-server
	service mariadb start
	if [ ! -f /var/lib/mysqldata/ibdata1 ]; then
		printf "\nY\nroot\nroot\nY\nY\nY\nY\n" > /tmp/dass
		mysql_secure_installation < /tmp/dass
		rm /tmp/dass
		echo "
		CREATE USER 'admin'@'localhost' IDENTIFIED BY 'root';
		GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' WITH GRANT OPTION;
		CREATE USER 'admin'@'172.20.0.%' IDENTIFIED BY 'root';
		GRANT ALL PRIVILEGES ON *.* TO 'admin'@'172.20.0.%' WITH GRANT OPTION;
		FLUSH PRIVILEGES;" | mysql -u root
	fi

	service mariadb stop
	update-rc.d -f mariadb remove
	systemctl disable mariadb
	#systemctl disable mysql
	if [ ! -f /var/lib/mysqldata/ibdata1 ]; then
		cp -r /var/lib/mysql/* /var/lib/mysqldata/
	fi
	# TODO: sed this bind-address            = 0.0.0.0
	sed -i 's|datadir[ \t]*= /var/lib/mysql|datadir         = /var/lib/mysqldata\ninnodb_use_native_aio=0\nlog-bin = binlog\nexpire-logs-days = 1\nmax-binlog-size  = 500M|g' /etc/mysql/mariadb.conf.d/50-server.cnf
fi

if [ $(contains "${services[@]}" "--apache2") == "y" ]; then
	# TODO: This is bulshit, we should only sync the sites_enabled folder
	if [ -d /etc/apache2/mods-enabled ]; then
		rm /etc/apache2/mods-enabled/*
	fi
	if [ -d /etc/apache2/conf-enabled ]; then
		rm /etc/apache2/conf-enabled/*
	fi
	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" -y install apache2
	a2enmod proxy_fcgi
	a2enmod ssl
	a2enmod rewrite
	service apache2 stop
	update-rc.d -f apache2 remove
	systemctl disable apache2
fi

if [ $(contains "${services[@]}" "--nginx") == "y" ]; then
	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" -y install nginx
	service nginx stop
	update-rc.d -f nginx remove
	systemctl disable nginx
fi

if [ $(contains "${services[@]}" "--php") == "y" ]; then
	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" -y install php-fpm php-mbstring php-imagick php-mysqli php-curl php-dom php-zip php-gd
	mv /etc/php/7.0/cli/php{.ini,.ini.old} 
	mv /etc/php/7.0/fpm/php{.ini,.ini.old}
	ln -s /vagrant/provisioning/php/php.ini /etc/php/7.0/cli/php.ini
	ln -s /vagrant/provisioning/php/php.ini /etc/php/7.0/fpm/php.ini
	service php7.0-fpm stop
	update-rc.d -f php7.0-fpm remove
	systemctl disable php7.0-fpm
	if [ $(contains "${services[@]}" "--apache2") == "y" ]; then
		sed -i 's|^listen = .*$|listen = 127.0.0.1:9000|g' /etc/php/7.0/fpm/pool.d/www.conf
	fi
	if [ $(contains "${services[@]}" "--nginx") == "y" ]; then
		sed -i 's|^listen = .*$|listen = /run/php/php7.1-fpm.sock|g' /etc/php/7.0/fpm/pool.d/www.conf
	fi
fi

if [ $(contains "${services[@]}" "--dotnet") == "y" ]; then
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.asc.gpg
	mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/
	wget -q https://packages.microsoft.com/config/debian/9/prod.list
	mv prod.list /etc/apt/sources.list.d/microsoft-prod.list
	apt-get update
	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" -y install dotnet-sdk-2.1
	#dotnet-hosting-2.0.6
fi

if [ $(contains "${services[@]}" "--docker") == "y" ]; then
	# official version
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
	apt-get update
	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" -y install docker-ce
	usermod -aG docker vagrant

	# DockerCompose
	#curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
	#chmod +x /usr/local/bin/docker-compose


	# AutoComplete
	#base=https://github.com/docker/machine/releases/download/v0.14.0 && curl -L $base/docker-machine-$(uname -s)-$(uname -m) >/tmp/docker-machine && install /tmp/docker-machine /usr/local/bin/docker-machine
	#base=https://raw.githubusercontent.com/docker/machine/v0.14.0
	#for i in docker-machine-prompt.bash docker-machine-wrapper.bash docker-machine.bash
	#do
	#  sudo wget "$base/contrib/completion/bash/${i}" -P /etc/bash_completion.d
	#done
	echo "docker"
fi

if [ $(contains "${services[@]}" "--aws-cli") == "y" ]; then
	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" -y install python-pip
	pip install awscli
fi

if [ $(contains "${services[@]}" "--apache2") == "y" ] || [ $(contains "${services[@]}" "--nginx") == "y" ]; then
	chown www-data:www-data /var/www
fi

if [ $(contains "${services[@]}" "--phpmyadmin") == "y" ] && [ ! -d /var/www/sites/phpMyAdmin ]; then
	phpMyAdminVersion="4.8.5"
	wget -O /tmp/phpMyAdmin.tar.gz "https://files.phpmyadmin.net/phpMyAdmin/${phpMyAdminVersion}/phpMyAdmin-${phpMyAdminVersion}-all-languages.tar.gz"
	remoteSha="`wget -qO- https://files.phpmyadmin.net/phpMyAdmin/${phpMyAdminVersion}/phpMyAdmin-${phpMyAdminVersion}-all-languages.tar.gz.sha256 | awk '{print $1}'`"
	localSha=`sha256sum /tmp/phpMyAdmin.tar.gz | awk '{print $1}'`

	if [ "${remoteSha}" == "${localSha}" ]; then
        tar xzvf /tmp/phpMyAdmin.tar.gz -C /var/www/sites
        mv "/var/www/sites/phpMyAdmin-${phpMyAdminVersion}-all-languages" "/var/www/sites/phpMyAdmin.local"
        rm /tmp/phpMyAdmin.tar.gz
        printf  "<?php\n\$cfg['Servers'][1]['auth_type'] = 'config';\n\$cfg['Servers'][1]['user'] = 'admin';\n\$cfg['Servers'][1]['password'] = 'root';\n\$cfg['Servers'][1]['host'] = 'localhost';\n\$cfg['Servers'][1]['compress'] = false;\n\$cfg['Servers'][1]['AllowNoPassword'] = false;" > /var/www/sites/phpMyAdmin.local/config.inc.php

        if [ $(contains "${services[@]}" "--nginx") == "y" ] && [ ! -f /etc/nginx/sites-enabled/phpmyadmin.local.conf ]; then
			cp /vagrant/provisioning/sites/phpmyadmin.local/nginx/phpmyadmin.local.conf /etc/nginx/sites-enabled/
		fi
    else
    	1>&2 echo "Error installing phpMyAdmin: Shasum does not match: local: ${localSha} remote: ${remoteSha}"
    fi
fi

# -- Leave jenkins for last so it is easy to find the admin password --------------------------------------------
if [ $(contains "${services[@]}" "--jenkins") == "y" ]; then
	# Install java
	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" -y install openjdk-8-jdk

	# install jenkins
	wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | apt-key add -
	sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
	apt update
	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" -y install jenkins
	echo "jenkins url: http://"$(get "${services[@]}" "--jenkins")":8080"
	echo "jenkins password: `cat /var/lib/jenkins/secrets/initialAdminPassword`"

	# TODO: put ssh keys somewhere in jenkins "home"???
fi	
