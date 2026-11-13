#!/bin/bash

# Get the hostname
hostname=$(hostname)

# Get the IP address
ip_address=$(hostname -I | awk '{print $1}')

os_name=$(grep PRETTY_NAME /etc/os-release | cut -d'=' -f2- | tr -d '"')
server=$(hostnamectl | grep "Virt")


echo " "
echo "Server Details"
echo "Hostname: $hostname"
echo "IP Address: $ip_address"
echo "OS Version (/etc/os-release): $os_name"
echo "Hardware Type:$server"
echo "ESXI_Server:ESXI5.STI.COM"
echo " "