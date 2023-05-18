#!/bin/bash

DB="/var/log/panels"

if [ ! -f "$DB.rrd" ]
then
	rrdtool create $DB.rrd --step 3600 \
		DS:detected:GAUGE:3600:U:U \
        DS:temp:GAUGE:3600:U:U \
        DS:frat:GAUGE:3600:U:U \
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
	echo "ExecStart=sudo python3 $PWD/monitor.py " >> panelmonitoring.service
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