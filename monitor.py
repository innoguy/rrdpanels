from select import select
from signal import signal, SIGINT
from socket import socket, AF_PACKET, SOCK_RAW, htons
from sys import exit
from os.path import exists
from os import system 
from datetime import datetime
from time import sleep

DB="/var/log/panels"
capture_window=3  # seconds to capture packet
heartbeat=30      # seconds sleep between captures
capture_space=60  # seconds between recorded values
dev = {'A':'enp5s0', 'B':'enp4s0'}

def hexstring(hexarray):
  return ''.join('{:02x}'.format(x) for x in hexarray)

def sigint_handler(signal, frame):
  exit(0)

def start():
  last = datetime.now()
  s = {}
  r = {}
  max_temp = {}
  min_fps = {}
  max_ifc = {}
  panels = {}
  panels['A'] = set()
  panels['B'] = set()

  s['A'] = socket(AF_PACKET, SOCK_RAW, htons(3))
  s['B'] = socket(AF_PACKET, SOCK_RAW, htons(3))

  s['A'].bind((dev['A'], 0))
  s['B'].bind((dev['B'], 0))

  max_temp['A'] = -100
  max_temp['B'] = -100

  min_fps['A'] = 100
  min_fps['B'] = 100

  max_ifc['A'] = 0
  max_ifc['B'] = 0

  while True:
    r['A'], _, _, = select([s['A']], [], [], 1.)
    r['B'], _, _, = select([s['B']], [], [], 1.)

    for p in ['A', 'B']:
      if len(r[p]) > 0:
        packet = s[p].recv(1500)
        src = packet[6:12]    # Source MAC address
        cmd = packet[14]      # Nucleus CMD

        eth_type = (packet[12] << 8) + packet[13]
        if (eth_type == 0x07d0 and src[0] == 0xe2 and src[1] == 0xff and cmd == 0x30):
          panels[p].add(src)

          _temp = packet[55:57]   # Temperature
          _fps = packet[141:143]  # FPS rate
          _ifc = packet[65:69]    # Incomplete frames counter

          max_temp[p] = max(int.from_bytes(_temp, 'little'), max_temp[p]) 
          min_fps[p]  = min(int.from_bytes(_fps, 'little'),  min_fps[p])
          max_ifc[p]  = max(int.from_bytes(_ifc, 'little'),  max_ifc[p])

          now = datetime.now()
          if (now - last).seconds >= capture_window:
            shell = "rrdtool updatev {}.rrd N:{}:{}:{}:{}:{}:{}:{}:{}".format(
              DB,
              len(panels['A']), float(max_temp['A'])/10, min_fps['A'], max_ifc['A'],
              len(panels['B']), float(max_temp['B'])/10, min_fps['B'], max_ifc['B'])
            print(shell)
            system(shell)
            panels.clear()
            sleep(heartbeat)
            last = datetime.now()

if __name__ == '__main__':
  signal(SIGINT, sigint_handler)
  start()
