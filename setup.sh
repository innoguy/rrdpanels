#!/bin/bash

DB="/var/log/cirrus-rrd/panels"
capture_window=1   # seconds to capture packet
heartbeat=300      # seconds sleep between captures
capture_space=600  # seconds between recorded values

# Stop installation if configured to monitor non-active port 
if [ $(cat /proc/net/dev | grep 'enp5s0' | awk '{print $2}') -eq 0 ]
then
	if [ ! -z "$( grep 'ports =' monitor.py | grep 'A')" ]
	then 
		echo "No traffic on port A, disable port A in monitor.py";
		exit 1
	fi 
fi
if [ $(cat /proc/net/dev | grep 'enp4s0' | awk '{print $2}') -eq 0 ]
then
	if [ ! -z "$( grep 'ports =' monitor.py | grep 'B')" ]
	then 
		echo "No traffic on port B, disable port B in monitor.py";
		exit 1
	fi 
fi

if [ ! -f "$DB.rrd" ]
then
	rrdtool create $DB.rrd --step $capture_space \
		DS:A_nbr:GAUGE:$capture_space:U:U \
        DS:A_temp:GAUGE:$capture_space:U:U \
        DS:A_fps:GAUGE:$capture_space:U:U \
		DS:A_ifc:COUNTER:$capture_space:U:U \
		DS:B_nbr:GAUGE:$capture_space:U:U \
        DS:B_temp:GAUGE:$capture_space:U:U \
        DS:B_fps:GAUGE:$capture_space:U:U \
		DS:B_ifc:COUNTER:$capture_space:U:U \
        RRA:AVERAGE:0.5:1:1000 
fi

if [ ! -f "$PWD/panelmonitoring.service" ]
then
	echo "[Unit]" > panelmonitoring.service
	echo "Description=Log panel monitoring values to round robin database" >> panelmonitoring.service
	echo "DefaultDependencies=no" >> panelmonitoring.service
	echo "After=network.target" >> panelmonitoring.service
	echo "" >> panelmonitoring.service
	echo "[Service]" >> panelmonitoring.service
	echo "ExecStart=$PWD/monitor.py" >> panelmonitoring.service
	echo "Restart=always" >> panelmonitoring.service
	echo "RestartSec=5s" >> panelmonitoring.service
	echo "[Install]" >> panelmonitoring.service
    echo "WantedBy=multi-user.target" >> panelmonitoring.service
fi

if [ ! -f "/etc/systemd/system/panelmonitoring.service" ]
then
    ln -s $PWD/panelmonitoring.service /etc/systemd/system/panelmonitoring.service
fi

sudo systemctl daemon-reload
sudo systemctl enable panelmonitoring
sudo systemctl start panelmonitoring
sudo systemctl status panelmonitoring