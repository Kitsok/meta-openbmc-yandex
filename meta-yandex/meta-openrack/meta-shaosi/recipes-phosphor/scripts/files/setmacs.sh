#!/bin/bash

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
cat << _EOF
This is script to set MAC addresses.
Warning: use with caution if running over ssh as you can loose the IP connectivity after!
_EOF

# Get addresses and serial
mac0_if=$(ifconfig eth0 2>&1| grep eth0 | awk '{print $5}' | tr '[:lower:]' '[:upper:]')
mac1_if=$(ifconfig eth1 2>&1| grep eth1 | awk '{print $5}' | tr '[:lower:]' '[:upper:]')

eeprom=$(cat /sys/class/i2c-dev/i2c-7/device/7-0056/eeprom | strings)
mac0_eep=$(echo ${eeprom} | sed 's/.*mac0=\([^ ]*\).*/\1/' | tr '[:lower:]' '[:upper:]')
mac1_eep=$(echo ${eeprom} | sed 's/.*mac1=\([^ ]*\).*/\1/' | tr '[:lower:]' '[:upper:]')
serial_eep=$(echo ${eeprom} | sed 's/.*serial=\([^ ]*\).*/\1/' | tr '[:lower:]' '[:upper:]')

env=$(fw_printenv)

mac0_env=$(echo ${env} | sed 's/.*ethaddr=\([^ ]*\).*/\1/' | tr '[:lower:]' '[:upper:]')
mac1_env=$(echo ${env} | sed 's/.*eth1addr=\([^ ]*\).*/\1/' | tr '[:lower:]' '[:upper:]')

echo "Current MACs & serial:"
echo "U-Boot Environment: MAC0=${mac0_env} MAC1=${mac1_env}"
echo "EEPROM:             MAC0=${mac0_eep} MAC1=${mac1_eep} Serial=${serial_eep}"
echo "ifconfig:           MAC0=${mac0_if} MAC1=${mac1_if}"
read -p "Press ENTER to continue or CTRL-C to terminate script " rc

read -p "Enter MAC0:" mac0
read -p "Enter MAC1:" mac1

echo "Going to write to EEPROM, U-Boot envinroment and set HW address on eth0 and eth1 interfaces."
echo "MAC0=${mac0}"
echo "MAC1=${mac1}"
read -p "Press ENTER to write data or CTRL-C to terminate script " rc

echo "Please wait, don't terminate the script"
# write data to eeprom (second half)
printf "mac0=$mac0\nmac1=$mac1\nserial=$serial_eep\n" | dd of=/sys/bus/i2c/devices/7-0056/eeprom bs=16k seek=1
fw_setenv ethaddr ${mac0}
fw_setenv eth1addr ${mac1}

echo "Data is written. Will reboot in 5 seconds. Press CTRL-C NOW to prevent reboot!!!"
sleep 5

echo "All is done. Rebooting. So Long, and Thanks for all the Fish."
/sbin/reboot

