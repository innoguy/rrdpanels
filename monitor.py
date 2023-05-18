from select import select
from signal import signal
from socket import socket
from sys import exit
from os.path import exists
from os import system 
from datetime import datetime
from time import sleep

def hexstring(hexarray):
  return ''.join('{:02x}'.format(x) for x in hexarray)

def sigint_handler(signal, frame):
  exit(0)

def start(eth, timeout):
  last = datetime.now()
  panels = set()


  s = socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3))
  s.bind((eth, 0))
  while True:
    r, _, _, = select.select([s], [], [], 1.)
    if len(r) > 0:
      packet = s.recv(1500)
      src = packet[6:12]    # Source MAC address
      cmd = packet[14]      # Nucleus CMD


      eth_type = (packet[12] << 8) + packet[13]
      if (eth_type == 0x07d0 and src[0] == 0xe2 and src[1] == 0xff and cmd == 0x30):
        panels.add(src)

        tmp = packet[55:57]   # Temperature
        fps = packet[141:143] # FPS rate

        temp = int.from_bytes(tmp, 'little') 
        frat = int.from_bytes(fps, 'little')

        now = datetime.now()
        if (now - last).seconds >= timeout:
          shell = "rrdtool updatev panels.rrd N:{}:{}:{}:{}:{}".format(len(panels),float(temp)/10,frat)
          system(shell)
          panels.clear()
          last = now
          sleep(30)

if __name__ == '__main__':
  signal(signal.SIGINT, sigint_handler)
  if not exists ("panels.rrd"):
    system("rrdtool create panels.rrd --step 60 "
           "DS:detected:GAUGE:60:U:U "
           "DS:temp:GAUGE:60:U:U "
           "DS:frat:GAUGE:60:U:U "
           "RRA:AVERAGE:0.5:1:1000")

  start("enp5s0", 2)
