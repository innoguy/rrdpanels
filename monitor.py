import argparse
import select
import signal
import socket
import sys
from os.path import exists
from os import system 

from datetime import datetime

def hexstring(hexarray):
  return ''.join('{:02x}'.format(x) for x in hexarray)

def sigint_handler(signal, frame):
  sys.exit(0)

def start(eth, timeout):
  last = datetime.now()
  panels = set()

  first_packet = True

  s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3))
  s.bind((eth, 0))
  while True:
    r, _, _, = select.select([s], [], [], 1.)
    if len(r) > 0:
      packet = s.recv(1500)
      dst = packet[:6]      # Destination MAC address
      src = packet[6:12]    # Source MAC address
      cmd = packet[14]      # Nucleus CMD


      eth_type = (packet[12] << 8) + packet[13]
      if (eth_type == 0x07d0 and src[0] == 0xe2 and src[1] == 0xff and cmd == 0x30):
        panels.add(src)

        tmp = packet[55:57]   # Temperature
        fps = packet[141:143] # FPS rate

        temp = int.from_bytes(tmp, 'little')
        frat = int.from_bytes(fps, 'little')

        if first_packet:
          temp_min = temp_max = temp 
          frat_min = frat_max = frat
          first_packet = False

        if temp < temp_min:
          temp_min = temp
        elif temp > temp_max:
          temp_max = temp

        if frat < frat_min:
          frat_min = frat
        elif frat > frat_max:
          frat_max = frat

        now = datetime.now()
        if (now - last).seconds >= timeout:
          shell = "rrdtool updatev panels.rrd N:{}:{}:{}:{}:{}".format(len(panels),temp_min,temp_max,frat_min,frat_max)
          system(shell)
          print('Number of detected panels  : {}'.format(len(panels)))
          print('Temperature range          : {} - {}'.format(temp_min, temp_max))
          print('FPS range                  : {} - {}'.format(frat_min, frat_max))
          panels.clear()
          first_panel=True
          last = now

if __name__ == '__main__':
  signal.signal(signal.SIGINT, sigint_handler)
  parser = argparse.ArgumentParser()
  parser.add_argument('-i', '--interface', type=str, help='Ethernet interface to monitor.')
  parser.add_argument('-t', '--time-interval', type=int, default=1, help='The time interval to monitor the detected panels.')
  args = parser.parse_args()
  if not exists ("panels.rrd"):
    system("rrdtool create panels.rrd --step 60 "
           "DS:detected:GAUGE:60:U:U "
           "DS:temp_min:GAUGE:60:U:U "
           "DS:temp_max:GAUGE:60:U:U "
           "DS:frat_min:GAUGE:60:U:U "
           "DS:frat_max:GAUGE:60:U:U "
           "RRA:AVERAGE:0.5:1:1000")

  if (args.interface == ""):
    iface = "enp5s0"
  else:
    iface = args.interface

  if (args.time_interval == ""):
    interval = 30
  else:
    interval = args.time_interval

  start(iface, interval)
