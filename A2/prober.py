#!/usr/bin/env python

from easysnmp import Session, EasySNMPTimeoutError
import sys
import time
import math

# Extract command line arguments
ip_address = sys.argv[1].split(':')[0]  # IP address of SNMP agent
remote_port = sys.argv[1].split(':')[1]  # Port of the SNMP agent
community = sys.argv[1].split(':')[2]  # Community of the SNMP agent

sampling_freq = float(sys.argv[2])  # Sampling frequency (Hz)
sampling_int = 1 / sampling_freq
samples = int(sys.argv[3])  # Number of samples to collect

# List of OIDs to query
list_oids = sys.argv[4:]
list_oids.insert(0, '1.3.6.1.2.1.1.3.0')  # SNMP uptime OID

# Create SNMP session
session = Session(hostname=ip_address, remote_port=remote_port, community=community, version=2, timeout=5, retries=1)
time_ticks11 = 0.0
timeout = False
i = 1
count = 0
oid_replies_old = []
old = []
out1 = []
time_start = time.time()

# Sleep until the next cycle based on the sampling interval
def sleep_until_next_cycle():
    now_time = time.time()
    time_until_now = now_time - time_start
    time_cycles_till_now = math.floor(float(time_until_now) / float(sampling_int))
    previous_cycle_time = time_start + time_cycles_till_now * sampling_int
    time_cycles_from_now_on = 1

    while True:
        next_cycle = previous_cycle_time + time_cycles_from_now_on * sampling_int
        sleep_interval = next_cycle - time.time()

        if sleep_interval <= 0:
            time_cycles_from_now_on += 1
        else:
            time.sleep(sleep_interval)
            return

# Main loop
while i <= samples:
    time_stamp_x = int(time.time())
    try:
        oid_replies = session.get(list_oids)
        new = oid_replies
        time_ticks22 = float(new[0].value)
    except EasySNMPTimeoutError:
        timeout = True
        continue

    time_stamp_y = int(time.time())
    response_time = time_stamp_y - time_stamp_x

    if len(new) == len(old):
        time_ticks = time_ticks22 - time_ticks11
        if time_ticks < 0:
            print("The Device has been Rebooted")
        else:
            timediff = max(time_stamp_x - t4, int(sampling_int))

            for x in range(1, len(list_oids)):
                if new[x].value != "NOSUCHINSTANCE" and old[x].value != "NOSUCHINSTANCE":
                    nvalue = int(new[x].value)
                    ovalue = int(old[x].value)
                    if nvalue >= ovalue:
                        out = (nvalue - ovalue) / timediff if timediff != 0 else 0
                    elif new[x].snmp_type == "COUNTER64":
                        out = ((2 ** 64 + nvalue) - ovalue) / timediff
                    elif new[x].snmp_type == "COUNTER":
                        out = ((2 ** 32 + nvalue) - ovalue) / timediff
                    else:
                        out = "N/A"
                    out1.append(out)
                else:
                    print(time_stamp_x, "| NOSUCHINSTANCE")
                    continue

            if len(out1) != 0:
                sar = [str(get) for get in out1]
                print(time_stamp_x, '|', " | ".join(sar))

    old = new[:]
    t4 = time_stamp_x
    out1.clear()

    if timeout:
        print("Timeout occurred")
        timeout = False

    sleep_until_next_cycle()
    time_ticks11 = time_ticks22
    i += 1
