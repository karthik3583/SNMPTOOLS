Sometimes it is desired to monitor custom metrics such as number of active HTTP connections etc., in addition to system metrics through SNMP. This allows for system as well as application monitoring through a common interface, SNMP. Through this assignment, students will learn to extend an SNMP agent to include custom OIDs to monitor such metrics.

In this assignment, students will model an SNMP counter and make it available through an enterprise OID. Firstly, write an SNMP subagent that responds to SNMP requests asking for the following enterprise OIDs:

 

1.3.6.1.4.1.4171.40.1	Value of (counter64) 1, i.e. y1=C1*Ty	
Note the difference! 

counter64 -> snmp v2 is needed. 

1.3.6.1.4.1.4171.40.2	Value of (counter64) 2, i.e. y2=C2*Ty	Counters start at 40.1
1.3.6.1.4.1.4171.40.3	Value of (counter64) 3, i.e. y3=C3*Ty	Time is at 50.1
....	....	+a new entity, 50.2
1.3.6.1.4.1.4171.40.N	Value of (counter64) N-1, i.e. yN=CN*Ty	
1.3.6.1.4.1.4171.50.1	
Value of (counter64) TyMicro, expressed in microseconds [us, 10e-6]

TyMicro = int(Ty*1e6);

Ty is a float, containing current timestamp including fractions. (See below)

 
1.3.6.1.4.1.4171.50.2	Number of counters found in the counters.conf file (in the example below it would be 3), an integer value	 
 

The values of the counters are generated based on the following function:

y(T)=C*Ty; 

Note: T will be a floating value, C is an Integer, y(Ty) will be a float. However, it has to be rounded to an integer, THEN store it into a 64-bit counter.  

Where,

Ty is the current time of the agent, in seconds, including fractions seconds, for example
$ date ; date +%s ; date +%s%N  ## Print current date (human format), then print the (current) date in 
                                ## seconds (%s), then the same and include nanoseconds (%N)
Fri, Jan 25, 2019 8:51:11 AM    ## < first date statement
1548402671                      ## < second date statement
1548402671727818800             ## < third date statement, but including and expressed in nanoseconds.
<different operations on the values to get the desired unit>
1548402671727818                ## time expressed in microseconds!!!! (here tval=torig/1000)
1548402671727                   ## time expressed in miliseconds!!!!  (here tval=torig/1e6)
1548402671                      ## time expressed in seconds!!!!      (here tval=torig/1e9)

Example two (Python), here. 
Example three (Perl), here. 
C is the bitrate of the process [0,10e16] bit/second. 
C is provided though a configuration file, 'counters.conf' that has the following format (ONLY and example, config file should handle N counters):

id,C	Description
1,10e6	for counter 1,C = 10Mbps
2, 5e6	for counter 2,C = 5Mbps
3,100e6	for counter 3,C = 100Mbps
 

Values of 'y' are the values of the counter. Secondly, configure SNMP agent to execute the subagent when an SNMP request is received. Furthermore, all OIDs within one request should use the same time value (Ty) for all calculations.

 
