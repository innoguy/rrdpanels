import argparse
import select
import signal
import socket
import sys

from datetime import datetime

def hexstring(hexarray):
  return ''.join('{:02x}'.format(x) for x in hexarray)

def sigint_handler(signal, frame):
  sys.exit(0)

def start(eth, timeout):
  last = datetime.now()
  panels = set()
  s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3))
  s.bind((eth, 0))
  while True:
    r, _, _, = select.select([s], [], [], 1.)
    if len(r) > 0:
      packet = s.recv(1500)
      dest = packet[:6] # Destination MAC address
      src = packet[6:12] # Source MAC address
      eth_type = (packet[12] << 8) + packet[13]
      if eth_type == 0x07d0 and src[0] == 0xe2 and src[1] == 0xff:
        panels.add(src)
      now = datetime.now()
      if (now - last).seconds >= timeout:
        print('Number of detected panels: {}'.format(len(panels)))
        panels.clear()
        last = now

if __name__ == '__main__':
  signal.signal(signal.SIGINT, sigint_handler)
  parser = argparse.ArgumentParser()
  parser.add_argument('-i', '--interface', type=str, help='Ethernet interface to monitor.')
  parser.add_argument('-t', '--time-interval', type=int, default=1, help='The time interval to monitor the detected panels.')
  args = parser.parse_args()
  start(args.interface, args.time_interval)
