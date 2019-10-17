#!/usr/bin/env python
# > libraries import
from easysnmp import *
import sys
import time
import math

# extract all the info from the command line parameters here
ip_address = sys.argv[1].split(':')[0]  # IP address of SNMP agent
remote_port = sys.argv[1].split(':')[1] # > port of the SNMP agent
community = sys.argv[1].split(':')[2] # > community of the SNMP agent

sampling_freq = float(sys.argv[2])  # handle between 10 and 0.1 Hz.
sampling_int = 1 / sampling_freq
samples = int(sys.argv[3])  # Samples (N) is the number of successful samples the solution should do before terminating
# should be greater than or equal 2

# > get a list of SNMP object from the command line
list_oids = sys.argv[4:]
# > add this SNMP object to the command line argument
# > this means the time (in hundredths of a second) since the network management portion of
# > the system was last re-initialized. 
# > reference: http://www.alvestrand.no/objectid/1.3.6.1.2.1.1.3.html
list_oids.insert(0, '1.3.6.1.2.1.1.3.0')
# Create an SNMP session to be used for all our requests
session = Session(hostname=ip_address, remote_port=remote_port, community='public', version=2,timeout=5, retries=1 )
time_ticks11 = 0.0
timeout = False
i = 1
count = 0
oid_replies_old = []
old = []
out1 = []
time_start = time.time()

# > this procedure sleeps n cycles according to the variable sampling_int 
def sleep_until_next_cycle():
    # get now time
    now_time = time.time()

    # compute how much time from the beginning
    time_until_now = now_time - time_start

    # compute the cycles that have passed
    time_cycles_till_now = math.floor(float(time_until_now) / float(sampling_int))

    # compute just the previous cycle point in time
    previous_cycle_time = time_start + time_cycles_till_now * sampling_int

    # set a counter for the next cycle (we are not sure it is the next as time runs)
    time_cycles_from_now_on = 1

    # loop to reach to a sleep
    while True:
        # compute next possible cycle (it is the previous one plus one, plus two, .....)
        next_cycle = previous_cycle_time + time_cycles_from_now_on * sampling_int

        # compute the time we have to sleep
        sleep_interval = next_cycle - time.time()

        # if it is zero (we are very lucky!!!) and directly return
        if sleep_interval == 0.0:
            return
        # if it is more than zero first sleep then return
        elif sleep_interval > 0.0:
            # print 'timeout time_to_sleep = ', time_to_sleep and then return
            time.sleep(sleep_interval)
            return

        # if less than zero then increment and recalculate
        time_cycles_from_now_on = time_cycles_from_now_on + 1

# > Main function
while i<= samples:

    # > start processsing all the samples
    time_stamp_x = int(time.time())
    try:
        # send a snmp request at a required sampling frequency
        # i.e send request every 1/sampling_freq time interval
        oid_replies = session.get(list_oids)
        # > new is the variable that will receive the request
        new = oid_replies
        # > time_ticks22 is the variable that will get the time since initialization
        time_ticks22 = float(new[0].value)
        # > set timeout to true if there is an error
    except EasySNMPTimeoutError:
        timeout = True
        pass
    time_stamp_y = int(time.time())

    response_time = time_stamp_y - time_stamp_x
    #try:
        
    #    time_ticks22 = float(session.get(['1.3.6.1.2.1.1.3.0'])[0].value)  
    #except:
    #    time_ticks22 = 0.0
    #    pass
    # lets do some stuff here
    #  print data
    if len(new) == len(old):
        # > get time difference between sample ticks
        time_ticks = time_ticks22 - time_ticks11
        # > if sample ticks is negative...
        if time_ticks < 0:
            print ("The Device has been Rebooted")
        else:
            # > calculate difference between the two samples
            if sampling_freq > 1:
                timediff = time_stamp_x - t4
            if sampling_freq <= 1:
                timediff1 = time_stamp_x - t4
                if timediff1 != 0:
                    timediff = timediff1
                else:
                    timediff = int(sampling_int)
            # > run a for each SNMP ID stored in array list_oids[]
            for x in range(1, len(list_oids)):
                # > if the object exists (different than NOSUCHINSTANCE result)...
                if new[x].value != "NOSUCHINSTANCE" and old[x].value != "NOSUCHINSTANCE":
                    # > assign new and old timestamp to variable nvalue and ovalue
                    nvalue = int(new[x].value)
                    ovalue = int(old[x].value)
                    # > if new timestamp is greater or equal than old...
                    if  nvalue>= ovalue:
                        # > if time difference is 0
                        if timediff == 0: 
                            # > output will be 0
                            out = 0
                        else:
                            # > output will be new value minus old value divided by time difference
                            out = ( nvalue- ovalue) / timediff
                            # > append to array out1[]
                        out1.append(out)
                    # > if the new timestamp is less than the old...
                    if nvalue < ovalue:
                        # > get SNMPv2 COUNTER64 object if it exists
                        if new[x].snmp_type == "COUNTER64":
                            out = ((2 ** 64 + nvalue) - ovalue) / timediff
                            # > append to the array out1[]
                            out1.append(out)
                        # > get SNMP COUNTER object if it exists
                        if new[x].snmp_type == "COUNTER":
                            out = ((2 ** 32 + nvalue) - ovalue) / timediff
                            # > append to the array out1[]
                            out1.append(out)
                else:
                    # > print timestamp if new value is equal to NOSUCHINSTANCE
                    print time_stamp_x, "|"
        # > increment count to get next sample
        i = i + 1
        # > if length of array out1[] is greater than zero
        if len(out1) != 0:
            # > print the array out1[]
            sar = [str(get) for get in out1]
            print time_stamp_x, '|', ("| ".join(sar))
    # > assing requests on the array new[] to the array old[] 
    old = new[:]
    # > assign end of loop time to t4
    t4 = time_stamp_x
    # > clean array out1[]
    del out1[:]

    if timeout:
        timeout = True
    # > call routine to sleep
    sleep_until_next_cycle()

    # > save time since last initialization for comparison at the beginning of the loop
    time_ticks11 = time_ticks22
    # > this command marks the end of the while loop
    pass




