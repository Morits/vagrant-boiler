#!/bin/bash
if [ ! -f /home/vagrant/etc.ext4.img ]; then
	if [ -f /vagrant/etc.ext4.img ]; then
		echo "copying image from: /vagrant/etc.ext4.img to: /home/vagrant"
		cp /vagrant/etc.ext4.img /home/vagrant
	else
		echo "etc image not found!"
	fi
fi

if [ ! -d /media/etc ]; then
	echo "mkdir /media/etc"
	mkdir /media/etc
fi

echo "mount -t ext4 -o loop /home/vagrant/etc.ext4.img /media/etc"
mount -t ext4 -o loop /home/vagrant/etc.ext4.img /media/etc