#!/usr/bin/perl

# > Program that listens for SNMP traps (configure snmptrapd appropri-
# > ately, the trap listener should be on port UDP:50162), the system should accept
# > all trap messages and log them to a SQLite database. The agents that may send traps to
# > you will send a status message. Use the enterprise MIB .1.3.6.1.4.1.41717.10.
# > SNMP traps are notification status messages sent from devices and captured by snmptrapd.
# >
# > SNMP trap Messages handled and their meaning:
# >
# > --- MIB specification
# > 1.3.6.1.4.1.41717.10.1 string 100 chars FQDN name of device reporting
# > 1.3.6.1.4.1.41717.10.2 integer 0...10 Status integer, 0=0k, 1=PROBLEM, 2=DANGER, 3=FAIL
# > 1.3.6.1.4.1.41717.20.3 integer 0...10 Previous status of device
# > 1.3.6.1.4.1.41717.20.3 unit32 4 bytes Unix time of manager for previous status message

# > Libraries Section

# > SNMP Interface Library
use Net::SNMP;
# > Embedded perl trap handling Libraryfor Net-SNMP's snmptrapd
use NetSNMP::TrapReceiver;
# > Database Library
use DBI;

# > SQLite database filename
my $db = "kook.db";

# > SQLite configuration
my $usrid = "";
my $pwd = "";
my $driver = "SQLite";

# > DBI datasource definition
my $dsn = "DBI:$driver:dbname=$db";

my $currentstatus; # > Variable for device status
my $currenttime; # > Variable for current time

# > Variables used to interact with database columns
my $dbh;
my $table;
my $create;
my $count;
my $FQDN;

# > Open/Create the SQLite table
$dbh = DBI->connect($dsn, $usrid, $pwd)
   or die $DBI::errstr;

# > Define the SQL needed to create the table that will hold device information
$table = qq(CREATE TABLE IF NOT EXISTS kook 
   (
      
      DeviceName               TEXT    NOT NULL,
      CurrentStatus            INT     NOT NULL,
      ReportTime        INT            NOT NULL,
      OldStatus         INT            NOT NULL,
      OldReportTime     INT            NOT NULL
      );
);
# > Create the table
$create = $dbh->do($table);

# > This subroutine is the trap receiver handler. It is called by this code:
# > NetSNMP::TrapReceiver::register("all", \&trap_receiver)
# > and receive all SNMP traps but only handles enterprise MIB .1.3.6.1.4.1.41717.10 (.1 and .2)

sub trap_receiver {

      # > @{$_[1]} is an array received by TrapReceiver. Loops over all the arguments.
      foreach my $x (@{$_[1]}) { 
          # > check for MIB .1 (FQDN)
          if ("$x->[0]" eq '.1.3.6.1.4.1.41717.10.1' ){ 
             $FQDN = $x->[1];
             $currenttime = time();             
      }
          # > check for MIB .2 (Status)
          if ("$x->[0]" eq '.1.3.6.1.4.1.41717.10.2' ){
             $currentstatus = $x->[1];
             
             }
      }

# > This regular expression searches for " character and replace with nothing, IE, erase 
# > all " from the FQDN

$FQDN =~ s/\"//gs;

# > debug messages commented
#print "$FQDN \n";
#print "$currentstatus \n";


# > Get total number of rows of SQL table kook
$count = $dbh->selectrow_array("SELECT COUNT(*)FROM kook");

###################################INSEERRT######################################

# > if total number of rows of table kook is equal zero
if($count==0){
# > assemble SQL query to insert device into table kook
$table = qq(INSERT  INTO kook(DeviceName,CurrentStatus,ReportTime,OldStatus,OldReportTime)VALUES ('$FQDN', '$currentstatus', '$currenttime', '$currentstatus', '$currenttime' ););


# > insert device into table
$create = $dbh->do($table);
#print "SUCCESFULLY INSERTED \n";
}
################################################################################
else{
# > initialize variable run to count table updates
$run = 0;
# > for each row in the table... 
for $i (1..$count)

{

# > create query to select all rows in the table
$table = qq(SELECT DeviceName,CurrentStatus,ReportTime,OldStatus,OldReportTime from kook;);
# > prepare query
$pre = $dbh->prepare( $table );
# > execute query, if unsucessful exit with error
$create = $pre->execute() 
or die $DBI::errstr; 

################################################################################
# > initialize empty device name array @devicename
@devicename =();
# > initialize empty state array @cstate
@cstate =();
# > initialize empty time array @ctime
@ctime=();

###############################################################################
# > get devicename, state and time and append to each array we initialized
while(@column = $pre->fetchrow_array()) {
      push(@devicename,$column[0]);
      push(@cstate,$column[1]);
      push(@ctime,$column[2]);}

###############################UPDATE##########################################

# > if the FQDN received by the trap receiver is equal to the last one in the array
if($FQDN eq @devicename[$i-1]){
# > assemble SQL query to update table kook rows CurrentStatus and ReportTime, 
# > also updates OldStatus and OldReportTime with the old state and time stored in the table
$table = qq(UPDATE kook set CurrentStatus = '$currentstatus', ReportTime = '$currenttime', OldStatus = '@cstate[$i-1]',OldReportTime = '@ctime[$i-1]'  where DeviceName = '$FQDN');
# > execute query, if unsucessful exit with error
$create = $dbh->do($table) or die $DBI::errstr;
# > increment table update variable
$run=$run+1;

#print "UPDATED SUCCESFULLY \n";
}
##############################################################################
else{
#print "NOTHING IS INSERTED \n";
}}
##########################################################################
# > check variable to see if table was updated, and if it was not updated...
if($run==0){


###########################INSERT######################################
# > assemble SQL query to insert device into table kook
$table = qq(INSERT  INTO kook(DeviceName,CurrentStatus,ReportTime,OldStatus,OldReportTime)
               VALUES ('$FQDN', '$currentstatus', '$currenttime', '$currentstatus', '$currenttime' ););
# > execute query
$create = $dbh->do($table);
#print "NEW DEVICE INSERTED SUCCESFULLY \n";
}}

#########################################################################


# > initialize array @output
@output = ();
# > initialize array @fail
@fail = ();
# > initialize array @danger
@danger =();




##################################FAIL##################################

# > assemble SQL query to select all devices with CurrentStatus = 3 (FAIL)
$table = qq(SELECT DeviceName,ReportTime,OldStatus,OldReportTime from kook WHERE CurrentStatus='3';);
# > prepare query
$pre = $dbh->prepare( $table );
# > execute query, quit if error
$create = $pre->execute() or die $DBI::errstr;
# > select total number of rows (count) returned by last query
$count = $dbh->selectrow_array("SELECT COUNT(*)FROM kook WHERE CurrentStatus = '3';");
# > initialize array row to store values from query
@row=();

# > loop start to get rows from last query
for $i (1..$count)

{

# > append each line from last query into the array @row
push @row,$pre->fetchrow_array();

# > loop end
}

#print "@row \n";

# > loop start to get elements from array
for $j (0..$count-1)

{

# > points to the first element in the row that we added previously
# > TIP: x + 3 * x  =  4 * x
$j =$j+3*$j;

# > append to array @x corresponding DeviceName,ReportTime,OldStatus,OldReportTime on table KOOK with status = 3 (FAIL)
# > --- MIB specification
# > 1.3.6.1.4.1.41717.10.1 string 100 chars FQDN name of device reporting
# > 1.3.6.1.4.1.41717.10.2 integer 0...10 Status integer, 0=0k, 1=PROBLEM, 2=DANGER, 3=FAIL
# > 1.3.6.1.4.1.41717.20.3 integer 0...10 Previous status of device
# > 1.3.6.1.4.1.41717.20.3 unit32 4 bytes Unix time of manager for previous status message

@x = ("1.3.6.1.4.1.41717.20.1",OCTET_STRING,"$row[$j]","1.3.6.1.4.1.41717.20.2",TIMETICKS,"$row[$j+1]","1.3.6.1.4.1.41717.20.3",INTEGER,"$row[$j+2]","1.3.6.1.4.1.41717.20.4",TIMETICKS,"$row[$j+3]");

# > append array @x to array @fail
push @fail, @x;

# > loop end 
}

#print "@fail \n";

#@row = ();

#@x= ();

# > append array @fail to array @output.
push @output,@fail;
#######################################################################################
#if($FQDN eq @devicename[$i-1]){

#$table = qq(UPDATE kook set CurrentStatus = '$currentstatus', ReportTime = '$currenttime', OldStatus = '@cstate[$i-1]',OldReportTime = '@ctime[$i-1]'  where DeviceName = '$FQDN');

#$create = $dbh->do($table) or die $DBI::errstr;

#$run=$run+1;

#print "UPDATED SUCCESFULLY \n";







#######################################DANGER############################################
# > assemble SQL query select devices with CurrentStatus = DANGER and OldStatus != FAIL
# > --- MIB specification
# > 1.3.6.1.4.1.41717.10.2 integer 0...10 Status integer, 0=0k, 1=PROBLEM, 2=DANGER, 3=FAIL

$table = qq(SELECT DeviceName,ReportTime,OldStatus,OldReportTime from kook WHERE CurrentStatus='2' AND OldStatus !='3';);

# > prepare query
$pre = $dbh->prepare( $table );
# > execute query or quit with error
$create = $pre->execute() 
or die $DBI::errstr;
# > select how many rows were returned from the last query
$count = $dbh->selectrow_array("SELECT COUNT(*)FROM kook WHERE CurrentStatus = '2' AND OldStatus!=3");

# > points to the first element in the row that we will use later
$w=1;
#print "$count \n";
# > initialize array @ro that will store last row results
@ro = ();

# > loop start to get elements from array
for $i (1..$count)

{
# > append each line from last query into the array @ro
push @ro,$pre->fetchrow_array();

# > loop end 
}

#print "@ro\n";
# > gets first row result stored in array @ro
$str=@ro;

# > while there are rows...
while($w<=$str){
# > append to array @dangertrp corresponding DeviceName,ReportTime,OldStatus,OldReportTime on table kook
# > with CurrentStatus = DANGER and OldStatus != FAIL
# > --- MIB specification
# > 1.3.6.1.4.1.41717.10.1 string 100 chars FQDN name of device reporting
# > 1.3.6.1.4.1.41717.10.2 integer 0...10 Status integer, 0=0k, 1=PROBLEM, 2=DANGER, 3=FAIL
# > 1.3.6.1.4.1.41717.20.3 integer 0...10 Previous status of device
# > 1.3.6.1.4.1.41717.20.3 unit32 4 bytes Unix time of manager for previous status message
@dangertrp = (".1.3.6.1.4.1.41717.30.".($w),OCTET_STRING,"@ro[$w-1]",".1.3.6.1.4.1.41717.30.".($w+1),TIMETICKS,"@ro[$w]",".1.3.6.1.4.1.41717.30.".($w+2),INTEGER,"@ro[$w+1]",".1.3.6.1.4.1.41717.30.".($w+3),TIMETICKS,"@ro[$w+2]");

# > append array @dangertrp to array @danger
push @danger,@dangertrp;

# > get next 4 rows
$w=$w+4;
# > end while
}

# > append array @danger to array @output
push @output,@danger;
# > print array @output
print "@output \n"; 



######################################traps##########
# > assemble SQL query to select all rows from table GET
$table = qq(SELECT * from GET;);
# > prepare query
$pre = $dbh->prepare( $table );
# > execute query or quit with error
$create = $pre->execute() 
or die $DBI::errstr;


# > while loop: get all rows from the last query
while(@column = $pre->fetchrow_array()) {
      # > append each row to @port, @ip and @community array
      push(@port,$column[2]);
      push(@ip,$column[1]);}
      push(@community,$column[0]);
# > create new SNMP object with ip found in last database query or default
# > values 'localhost', 'public', 'port'
my ($session, $error) = Net::SNMP->session(
      -hostname  => @ip[0] || 'localhost',
      -community => @community[0] || 'public',
      -port      => @port[0] || 'port'
   );
# > if cannot create SNMP object, exit with error
if (!defined $session) {
      printf "ERROR: %s.\n", $error;
      exit 1;
   }
else {
# > else prints...
print "session created \n";
}
# > send a SNMP trap to the remote manager with the @output array we previously assembled
# > reference: http://search.cpan.org/~dtown/Net-SNMP-v6.0.1/lib/Net/SNMP.pm#trap()_-_send_a_SNMP_trap_to_the_remote_manager
my $result = $session->trap(
                          -varbindlist => \@output
                           );
# > if not sucessful, quit with error                           
if (!defined($result)){print "An erroe occurred:" . $session->error();}
# > else prints...
else{print "successful \n";}

}
# > End of trap_receiver 

# > register subroutine trap_receiver into the Net-SNMP snmptrapd process.
# > reference: http://search.cpan.org/~hardaker/NetSNMP-TrapReceiver-5.0301/TrapReceiver.pm
NetSNMP::TrapReceiver::register("all", \&trap_receiver) ||
# > if not sucessful, print...
warn "failed to register trap\n";
# > prints...
print STDERR "Snmp trap handler running succesfully\n";






