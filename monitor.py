from select import select
from signal import signal, SIGINT
from socket import socket, AF_PACKET, SOCK_RAW, htons
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

  s = socket(AF_PACKET, SOCK_RAW, htons(3))
  s.bind((eth, 0))
  while True:
    r, _, _, = select([s], [], [], 1.)
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
          shell = "rrdtool updatev panels.rrd N:{}:{}:{}".format(len(panels),float(temp)/10,frat)
          system(shell)
          panels.clear()
          last = now
          sleep(1800)

if __name__ == '__main__':
  signal(SIGINT, sigint_handler)
  start("enp5s0", 2)
