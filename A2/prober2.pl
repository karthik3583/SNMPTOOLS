#!/usr/bin/perl

use strict;
use warnings;

my $DEBUG = $ENV{'DEBUG'};
$DEBUG = 0 unless defined($DEBUG);

use Net::SNMP;
use Time::HiRes qw /gettimeofday nanosleep time/;
use Math::Round;
use POSIX qw / ceil /;
use POSIX qw / fmod /;

die "Usage: $0 ip:port:community freq count OID [...]\n" unless defined($ARGV[3]);
my ($IP, $PORT, $COMMUNITY) = split /[:]/,$ARGV[0];
my $FREQ = $ARGV[1] * 1000000000;
my $NUM_SAMPLES = $ARGV[2];

my $SAMPLE = 0;
my $TIMEOUT = 10;
my @LIST;
my $timeticks = 0;

@LIST = map {$ARGV[$_]} (3..$#ARGV);
# Check if all oids have prepended 
for(my $i=0; $i<=$#LIST; $i++) {
    my $oid = $LIST[$i];
    $LIST[$i] = '.' . $oid unless ($LIST[$i] =~ /^\..*/);
}

my @previous;
my @current;
my $snmpUptime;
my $lastRequestTime;
my $timeoutR = 0;

# Main loop
while(1) {
    exit if ($NUM_SAMPLES != -1 and $SAMPLE >= $NUM_SAMPLES+1);
    $SAMPLE++;

    my $ret = connect_to_snmp();
    my $snmpResponse = $ret;
    
    my @out = ();
    push @out, time();
    
    # Handle SNMP timeout
    if ($ret == -1) {
        push @out, "TIMEOUT, Ts=$TIMEOUT R=$timeoutR";
        $timeoutR++;
        print join(' | ', @out),"\n";
        nanosleep($FREQ);
        next;
    } else {
        $timeoutR = 0;
    }


    @current = ();
    
    my $oid_snmpUptime = $snmpResponse->{'.1.3.6.1.2.1.1.3.0'};
    my $oid_SystemTime = $snmpResponse->{'.1.3.6.1.4.1.4171.50.1'};
    delete $snmpResponse->{'.1.3.6.1.2.1.1.3.0'};
    delete $snmpResponse->{'.1.3.6.1.4.1.4171.50.1'};

    foreach my $oid (@LIST) {
        push @current,$snmpResponse->{$oid};
    }

    # Handle first request
    if (scalar @previous == 0) {
        $snmpUptime = $oid_snmpUptime;
        $lastRequestTime = $oid_snmpUptime;
        @previous = @current;
        next;
    }

    if ($oid_snmpUptime < $timeticks)  {
        push @out,"RESTART/REBOOT";
        @previous = ();
        @current = ();
        print join(' | ', @out),"\n";
        next;                                             
    }

    #    my $timeDiff = ($oid_SystemTime - $lastRequestTime) / 1e6;	# per second rate
     my $timeDiff = ($oid_snmpUptime - $timeticks)/100;	# per microsecond rate
    $timeticks = $oid_snmpUptime;
	if ($timeDiff !=0){
			my $inter_TS = round($timeDiff);
			
			if ($ARGV[1]== 2){
				$inter_TS = $timeDiff;
			}
    

    for(my $i=0; $i<=$#current; $i++) {
        my $rate;
#        ($current[$i] eq "Incorrect OID Entered") ? ($rate = "N/A") : ($rate = ($current[$i] - $previous[$i]) / $timeDiff);
        if (($current[$i] eq "Incorrect OID Entered") or (int($inter_TS) == 0)) {
		$rate = "N/A";
	} else {
		if ($current[$i] < $previous[$i]) {
			# Assume that if previous value less than 32-bit before
			# its value wrap, then it's more likely to be 32-bit counter
			# if its value larger than 32-bit then, well, it has to be 64-bit counter
			if ($current[$i] <= (2**32 - 1)) {
				$rate = sprintf("%d", (2**32 + $current[$i] - $previous[$i]) / $inter_TS);
				push @out, ($rate);
			} else {
				$rate = sprintf("%d", (2**64 + ($current[$i] - $previous[$i])) / $inter_TS);
				push @out, ($rate);
			}
		} 
	}
        printf("DEBUG[%d] -> %d,%d:%d - $rate\n", $i,$current[$i],$previous[$i],$inter_TS) if $DEBUG;
        #push @out, ($rate);
    }

    print join(' | ', @out),"\n";
    @previous = @current;

    nanosleep($FREQ);
}

sub connect_to_snmp {
    my ($session, $error) = Net::SNMP->session(
        -hostname => $IP,
        -port     => $PORT,
        -community => $COMMUNITY,
        -version => "2c",
        -translate=> [-timeticks => 0x0],
    );

    die "ERROR: $error" if (!defined $session);
    
    $session->timeout([$TIMEOUT]);

    my @oids = (
        '1.3.6.1.2.1.1.3.0', 
        '1.3.6.1.4.1.4171.50.1',
        '1.3.6.1.4.1.4171',
        @LIST);
    my $snmpResponse = $session->get_request(
        -varbindlist      => \@LIST,
    );

    # my $types = $session->var_bind_types();
    #map {print "key: $_=>",$snmpResponse->{$_},"\n"} keys %$snmpResponse;
    
    return -1 if (!defined $snmpResponse);
    
    $session->close();
    return $snmpResponse;
}

}

