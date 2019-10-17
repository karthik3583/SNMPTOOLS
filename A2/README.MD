Write a script to probe the an SNMP agent and find the rate of change for several counters between successive probes/ samples. The rate calculated for each counter/OID should be displayed on the console, one line for each calculated rate, the output format will be described in detail in 'output format'. Futhermore, as the only requirement on the OIDs is that they are of the type COUNTER, this means that there are both 32 and 64 bit versions of counters. Your solution should handle both counter types, and in the case that a counter wraps (ie goes from a high number to a low number), your solution should address/rectify (if its possible). The solution needs also to handle that an SNMP agent restarts (i.e. the sysUpTime OID becomes less than it was before, ie. it starts counting from zero), and timeouts, i.e. the device does not respond to your request in time. It will be tested that your solution maintains the requested sampling frequency (i.e. the requests from your solution should be sent so that the sampling frequency is maintained, irrespectively if the device has responded or not). 

 

The script will be invoked as follows:

prober <Agent IP:port:community> <sample frequency> <samples> <OID1> <OID2> …….. <OIDn>

 

where,

IP, port and community are agent details,

OIDn are the OIDs to be probed (they are absolute, cf. IF-MIB::ifInOctets.2 for interface 2, or 1.3.6.1.2.1.2.2.1.10.2 [1]) 

Sample frequency  (Fs) is the sampling frequency expressed in Hz, you should handle between 10 and 0.1 Hz. 

Samples (N) is the number of successful samples the solution should do before terminating, hence the value should be greater or equal to 2. If the value is -1 that means run forever (until CTRL-C is pressed, or the app is terminated in someway). 

 

Following are the files to be submitted:  Note: The file has to be submitted with ".txt" extension so that plagiarism control will work.

prober.txt         	
Script that probes the agent, may be written in any language (perl, python,etc.), make use of the SHEBANG to handle what language interpreter that execute the script. 

If you use a complied language, make sure that the compiler outputs the correct filename on the executable. 

 

What ever language you choose to implement the solution in, make sure that you use a proper API for the SNMP communication, i.e. using system commands is not the way to do it. The aim is to train API interaction. 

 

Output format

The output from the script _MUST_ be as follows:

Sample time | OID1 | OID2 | .... | OIDn

 

Sample time: Timestamp from when the last sample/event was received, in seconds and micro-seconds.

OID*: Rate of OID* between the last two successful samples

 

As an example:

1504083911.010000  | 2124 | 819 | 0 | 281761 
1504083912.010000  | 2471 | 819 | 110 | 450782 
1504083913.010000  | 1904 | 819 | 2000 | 325448 
 

In the case a device restarts, then the output should indicate this, for example

1504083911.010000  | 2124 | 819 | 0 | 281761 
1504083912.010000  | RESTART/REBOOT 
1504083913.014000  | 1904 | 819 | 2000 | 325448
1504083914.020000  | 1214 | 159 | 2400 | 345648 

In the case a device Timeouts, then the output should indicate this, for example

1504083911.010000  | 2124 | 819 | 0 | 281761 
1504083922.020000  | TIMEOUT, Ts=10 R=0
1504083923.010000  | 1904 | 819 | 2000 | 325448
1504083924.030000  | 1214 | 159 | 2400 | 345648 

There Ts shows the timeout time, and R the number of retries used. 

 

If your solution happens to probe a non existing OID, then this should be shown via a 'N/A' note. 

1504083911.010000  | 2124 | N/A | 0 | 281761 
1504083912.010000  | 2471 | N/A | 110 | 450782 
1504083913.010000  | 1904 | N/A | 2000 | 325448 
 
