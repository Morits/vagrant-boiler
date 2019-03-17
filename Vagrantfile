# For passwordless ups enter these lines in your sudoers file: /etc/sudoers using visudo
# macOS:
=begin
# let vagrant create nfs exports
Cmnd_Alias VAGRANT_EXPORTS_ADD = /usr/bin/tee -a /etc/exports
Cmnd_Alias VAGRANT_NFSD = /sbin/nfsd restart
Cmnd_Alias VAGRANT_EXPORTS_REMOVE = /usr/bin/sed -E -e /*/ d -ibak /etc/exports
%admin ALL=(root) NOPASSWD: VAGRANT_EXPORTS_ADD, VAGRANT_NFSD, VAGRANT_EXPORTS_REMOVE
=end

# Ubuntu / Debian:
=begin
# let vagrant create nfs exports
Cmnd_Alias VAGRANT_EXPORTS_CHOWN = /bin/chown 0\:0 /tmp/*
Cmnd_Alias VAGRANT_EXPORTS_MV = /bin/mv -f /tmp/* /etc/exports
Cmnd_Alias VAGRANT_NFSD_CHECK = /etc/init.d/nfs-kernel-server status
Cmnd_Alias VAGRANT_NFSD_START = /etc/init.d/nfs-kernel-server start
Cmnd_Alias VAGRANT_NFSD_APPLY = /usr/sbin/exportfs -ar
%sudo ALL=(root) NOPASSWD: VAGRANT_EXPORTS_CHOWN, VAGRANT_EXPORTS_MV, VAGRANT_NFSD_CHECK, VAGRANT_NFSD_START, VAGRANT_NFSD_APPLY
=end

# Fedora:
=begin
# let vagrant create nfs exports
Cmnd_Alias VAGRANT_EXPORTS_CHOWN = /bin/chown 0\:0 /tmp/*
Cmnd_Alias VAGRANT_EXPORTS_MV = /bin/mv -f /tmp/* /etc/exports
Cmnd_Alias VAGRANT_NFSD_CHECK = /usr/bin/systemctl status --no-pager nfs-server.service
Cmnd_Alias VAGRANT_NFSD_START = /usr/bin/systemctl start nfs-server.service
Cmnd_Alias VAGRANT_NFSD_APPLY = /usr/sbin/exportfs -ar
%vagrant ALL=(root) NOPASSWD: VAGRANT_EXPORTS_CHOWN, VAGRANT_EXPORTS_MV, VAGRANT_NFSD_CHECK, VAGRANT_NFSD_START, VAGRANT_NFSD_APPLY
=end

# -- Configuration ------------------------------------------------------------------------------
boxName = "boiler.box"
# Define what services you want in the box. Options are: apache2 | nginx | mysql | dotnet  | php | node
services = [
  "mysql",
  "nginx",
#  "apache2",
#  "dotnet",
  "php",
#  "node",
#  "docker",
  "phpmyadmin",
  "aws-cli",
];
ip = "192.168.33.10"

# -- Dragons ahead ------------------------------------------------------------------------------
# https://stackoverflow.com/questions/26811089/vagrant-how-to-have-host-platform-specific-provisioning-steps
module OS
    def OS.windows?
        (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    end

    def OS.mac?
        (/darwin/ =~ RUBY_PLATFORM) != nil
    end

    def OS.unix?
        !OS.windows?
    end

    def OS.linux?
        OS.unix? and not OS.mac?
    end
end


Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-17.10"

  config.vm.define boxName
  config.vm.hostname = boxName
  config.vm.box_check_update = false
  config.vm.network "private_network", ip: ip

  if services.include? "dotnet"
    config.ssh.extra_args = ["-L" "5000:localhost:5000" ]
  end 

  config.vm.provider "virtualbox" do |v|
    v.memory = 512
    v.cpus = 4
  end
  
  # set up port forwarding for xdebug listener
  config.ssh.extra_args = "-R 9000:localhost:9000"

  # Setup mysql shares (nfs on mac, *nix or smb in windows)
  if services.include? "mysql"
    if OS.windows?
      config.vm.synced_folder "./mysql/", "/var/lib/mysqldata", create: true, type: "smb",
      owner: 113, group: 117,
      smb_password: "v4grant!", smb_username: "Vagrant",
      mount_options: ["username=Vagrant","password=v4grant!"]
    else
      config.vm.synced_folder "./mysql/", "/var/lib/mysqldata", create: true, 
      #owner: 113, group: 117, 
      type: "nfs" 
    end
    # "hostpath", "guestpath"
    config.vm.synced_folder "./var/log/mysql", "/var/log/mysql", create: true, owner: 113, group: "adm"
  end

  if services.include? "apache2"
    config.vm.synced_folder "./var/log/apache2", "/var/log/apache2", create: true, owner: "root", group: "adm", mount_options: ["dmode=755,fmode=644"]
  end

  if services.include? "nginx"
    config.vm.synced_folder "./var/log/nginx", "/var/log/nginx", create: true, owner: 33, group: "adm"
  end

  if services.include? "php"
    config.vm.synced_folder "./var/log/php", "/var/log/php", create: true, owner: "root", group: "root"
  end

  # Sites
  config.vm.synced_folder "./sites", "/var/www/sites", create: true, owner: 33, group: 33

  # mount etc.ext4.img. This scripts move the img to HOME then mounts it
  config.vm.provision :shell, run: "always", path: "mount.sh"

  provisionArgs = ""
  services.each { |x|
    provisionArgs = provisionArgs + " --" + x
  }
  config.vm.provision :shell, path: "bootstrap.sh", :args => provisionArgs

  if services.include? "apache2"
    config.vm.provision "shell", run: "always", inline: "service apache2 start"
  end
  if services.include? "nginx"
    config.vm.provision "shell", run: "always", inline: "service nginx start"
  end
  if services.include? "php"
    config.vm.provision "shell", run: "always", inline: "service php7.1-fpm start"
  end
  if services.include? "mysql"
    config.vm.provision "shell", run: "always", inline: "service mariadb start"
    config.vm.provision "shell", run: "always", inline: "echo 'PURGE BINARY LOGS BEFORE NOW()' | mysql -u root"
  end

  config.trigger.before :halt, :suspend, :destroy do |trigger|
      trigger.info = "Copying etc.ext4.img back to /vagrant/etc.ext4.img"
      trigger.run_remote = {inline: "cp /home/vagrant/etc.ext4.img /vagrant/"}
  end 
end
