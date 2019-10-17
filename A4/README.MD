Create a system that listens for SNMP traps (configure snmptrapd appropriately, the trap listener should be on port UDP:50162), the system should accept all trap messages. The agents that may send traps to you will send a status message. The message is sent as a string,  containing the FQDN of the reporting device, followed by a integer indicating staus. Use the enterprise MIB “.1.3.6.1.4.1.41717.10” and “.1.3.6.1.4.1.41717.20”  to send the messages, see Table 1 for specifications (see Figure 1 for an example how to send a trap from command line).

A device normally alternates between the OK or PROBLEM, occasionally it can go into DANGER, or in the worst case it goes into FAIL. The receiving system should keep track of what the agents report.

From a simple webpage (getStatus.php) (easy for a machine to read) is should be possible to see the current status of all device that have reported. If any device reports FAIL, a trap, using the MIB in Table 2, should be sent from the manager to another device, called TrapDestination. To configure the communication information to reach this device (TrapDestination), use setTrapR.php?ip=<ip of receiver>&port=<port>&community=<community>. The configuration of the TrapDestination should be readable via getTrapR.php. (For details on input/output of {set/get}TrapR.php see below). 

 

If two (or more) devices are in the DANGER state a trap should be sent, to the same device, send ONE trap for ALL devices, using MIB in Table 3.I.e. When you go from one danger device, too two, send a trap. If you go from 2 too 3, send a trap. But if you go from 3 to 2, you should not to send a trap.. 

 

Hence your solution should have three webpages/URI/scripts; 

getStatus.php

setTrapR.php 

getTrapR.php 

 

(and config.php for simplifying DB access)

 

 

getStatus.php has no input, but the the output of getStatus.php is either FALSE (if no devices have been logged) or a list of devices in the the following format of: 

<device name1> | <status> | <report time of status> | <oldstatus (if applicable)> | <old report time (if applicable)>
<device name2> | <status> | <report time of status> | <oldstatus (if applicable)> | <old report time (if applicable)>

....

<device nameK> | <status> | <report time of status> | <oldstatus (if applicable)> | <old report time (if applicable)>

 

where 

device name is the name provided in the trap

status is the numerical status provided in the trap

report time of status is the time the trap containing the status was recieved by the system. 

oldstatus is the previous status, if the device had any.

old report time is the time when the old data was reported..

 

the input/output of setTrapR.php

Sent: setTrapR.php?ip=<ip of receiver>&port=<port>&community=<community>

Reply; OK or FALSE

 

getTrapR.php has no input, but the reply is like: community@IP:PORT or FALSE. For example, if TrapDestination is 127.0.0.1:50000 with community Kyoto, the reply should be "Kyoto@127.0.0.1:50000". If no TrapDestination has been set, the reply should be "FALSE". 

 

Notes/Clarifications: 

Clarifications were made wrt. the MIBs to use when send traps. Please note that the DANGER trap used a different MIB. 

 

Following are the files to be submitted:  Note: All files to be submitted with ".txt" extension so that plagiarism control will work.

getStatus.php.txt	web page
setTrapR.php.txt	web page
getTrapR.php.txt	web page
config.php.txt	configuration file used for simplifying DB usage
snmptrapd.conf.txt	snmptrapd config file
traphandler.txt	solution that will handle the traps
 

 

 

--Technical Testing--

You solution will be tested by an script. At first the script will deploy your solution, all files, into a random folder. It will then strip the ",txt" extention from all of the files. 

I'll use the built-in webserver in PHP7, i.e. php -S <ip:port>, and execute it in that directory. 

Use an SQLite3 database, you are allowed to create/write files in the directory where the solution executes. This gives you complete control of the tables (and simplifies my testing), but you need to create the database and tables. 

The first thing script will do is to send an request to getStatus.php, at this point is just expects an reply, but no content (allowing you to create the tables, if needed). 

The script will then start the snmptrapd using your config file as input, it will be called as

"sudo snmptrapd -Onvq -f -c snmptrapd.conf -C -a -Lf snmptrapd.log &"

 

In the next stage, the script will first set the trap receiver (setTrapR.php), and shortly afterward verify that it was correcty set (getTrapR.php)

 

It will then issue a sequence of traps to the daemon and after each trap message sent verify that the status has been updated appropriately. If traps are to be send, another script will verify that the traps were sent and received by a controlled trap receiver. --It is important that you snmptrapd listens to all interfaces, not just localhost ---

 

 

 

 

Table 1: MIB - To Receiver
OID	TYPE	Size	Description
.1.3.6.1.4.1.41717.10.1	string	100 chars	FQDN name of device reporting
.1.3.6.1.4.1.41717.10.2	integer	0...10	
Status integer, 0=0k, 1=PROBLEM,

2=DANGER, 3=FAIL

 

Table 2: MIB - From Receiver if FAIL	 	 	 
.1.3.6.1.4.1.41717.20.1	string	200 chars	FQDN of device with FAIL
.1.3.6.1.4.1.41717.20.2	uint32	4 bytes	Unix time of manager when received FAIL
.1.3.6.1.4.1.41717.20.3	integer	0...10	Previous status of device
.1.3.6.1.4.1.41717.20.4	uint32	4 bytes	Unix time of manager for previous status message
 	 	 	 
 

Table 3: MIB - From Receiver if DANGER	 	 	 
.1.3.6.1.4.1.41717.30.1	string	200 chars	FQDN of device1 with DANGER
.1.3.6.1.4.1.41717.30.2	uint32	4 bytes	Unix time of manager when received FAIL
.1.3.6.1.4.1.41717.30.3	integer	0...10	Previous status of device 1
.1.3.6.1.4.1.41717.30.4	uint32	4 bytes	Unix time of manager for previous status message
.1.3.6.1.4.1.41717.30.5	string	200 chars	FQDN of device2 with DANGER
.1.3.6.1.4.1.41717.30.6	uint32	4 bytes	Unix time of manager when received FAIL
.1.3.6.1.4.1.41717.30.7	integer	0...10	Previous status of device 2
.1.3.6.1.4.1.41717.30.8	uint32	4 bytes	Unix time of manager for previous status message
....	 	 	 
.1.3.6.1.4.1.41717.30.(n*4)	string	200 chars	FQDN of deviceN with DANGER
.1.3.6.1.4.1.41717.30.(n*4+1)	uint32	4 bytes	Unix time of manager when received FAIL
.1.3.6.1.4.1.41717.30.(n*4+2)	integer	0...10	Previous status of device N
.1.3.6.1.4.1.41717.30.(n*4+3)	uint32	4 bytes	Unix time of manager for previous status message

 

snmptrap -v 1 -c public 127.0.0.1:50162 .1.3.6.1.4.1.41717.10 10.0.2.3 6 247 ' ' .1.3.6.1.4.1.41717.10.1 s "bubbly.bth.se" .1.3.6.1.4.1.41717.10.2 i "1"

Fig1: Example of sending a SNMPtrap message. 
