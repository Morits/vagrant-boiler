#!/bin/bash
if [ ! -f /home/vagrant/etc.ext4.img ]; then
	if [ -f /vagrant/etc.ext4.img ]; then
		cp /vagrant/etc.ext4.img /home/vagrant
	else
		echo "etc image not found!"
	fi
fi

if [ ! -d /media/etc ]; then
	mkdir /media/etc
fi	

part="p1"
looif=`losetup -fP --show /home/vagrant/etc.ext4.img`
mount "$looif$part" /media/etc