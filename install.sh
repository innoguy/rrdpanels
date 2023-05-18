#!/bin/bash

if [ ! -f "$PWD/panelmonitoring.service" ]
then
	echo "[Unit]" > panelmonitoring.service
	echo "Description=Log panel monitoring values to round robin database" >> panelmonitoring.service
	echo "DefaultDependencies=no" >> panelmonitoring.service
	echo "After=network.target" >> panelmonitoring.service
	echo "" >> panelmonitoring.service
	echo "[Service]" >> panelmonitoring.service
	echo "ExecStart=$PWD/sudo python3 monitor.py " >> panelmonitoring.service
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
sudo systemctl enable rrd
sudo systemctl start rrd
sudo systemctl status rrd