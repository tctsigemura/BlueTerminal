#!/bin/bash
/bin/echo -n your name\(Within 8 characters\):
read name
if [ `expr ${name} : .\*` -gt 8 ]; then
  echo \"${name}\" is too long.
  exit 1
fi

/bin/echo -n Please wait 5 seconds...
(echo sf,2
sleep 1
echo sr,32104c00
sleep 1
echo sn,${name}
sleep 1
echo sp,0
sleep 1
echo r,1
sleep 1) > /dev/cu.usbserial-*
/bin/echo

