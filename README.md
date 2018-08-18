# Vagrant Boilerplate
Vagrant boilerplate for easy setup of [ lamp | lemp | node | docker | dotnet ] dev enviroment

Install Vagrant and VirtualBox
* https://www.vagrantup.com/
* https://www.virtualbox.org/

Edit Vagrantfile.
Set the box name and services you want
```
boxName = "boiler.box"
services = [
#  "mysql",
#  "nginx",
#  "apache2",
#  "dotnet",
#  "php",
#  "node",
#  "docker"
#  "phpmyadmin"
];
```
```
$ vagrant up
```