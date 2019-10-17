#! /usr/bin/perl -w

use Net::SNMP;
use Time::HiRes qw /gettimeofday nanosleep time/;
use Math::Round;
use POSIX qw / ceil /;
use POSIX qw / fmod /;
no warnings qw(uninitialized);



my @list = (); 
my @oid = ();
my $sample = 0;
my $loop = 1; 
my $timeticks = 0;
my $result;
my $restart = 0;
my $timeout = 5;   
my $retries = 0;

my @agentdetails = split /[:]/,$ARGV[0];
my ($ip,$port,$community) = @agentdetails;
my $freq = 1/$ARGV[1];  
my $req_samples = $ARGV[2];



push(@list,"1.3.6.1.2.1.1.3.0");

foreach $oid(3 .. $#ARGV)                       
{
	push(@list,$ARGV[$oid]);
	$oid{"$ARGV[$oid]"} = 0;
}

my $starttime= gettimeofday();



while () 
{
	$starttime = gettimeofday();
	$result = get_Session() or die "Cannot define SNMP session to defined host: $result!\n";
	$result = get_Request();
	set_Val();
	if ($result == 0) {
		$retries++;
	} else {
		$retries = 0;
	}
}



sub get_Session {
	($session, $error) = Net::SNMP->session(
						-hostname  => $ip,
						-port      => $port,
						-community => $community,
						-version   => "2c",
						-timeout   => $timeout,
						-retries   => 0,
						-translate=> [-timeticks => 0x0]);

	if (defined($session)){
		return 1;
	}
	else {
		return $error;
	}
}


	
sub get_Request {
	$res = $session->get_request(
		  -varbindlist  => \@list,
		);
	$types = $session->var_bind_types();
	
	if(defined($res)){
		return 1;
	}
	else {
		return 0;
	}
}


sub set_Val {
	if ( $result == 1 and $res->{'1.3.6.1.2.1.1.3.0'} < $timeticks)  {    
		$loop = 1; 
		$timeticks = 0;
		$restart = 1;
	}
	$timediff = (($res->{'1.3.6.1.2.1.1.3.0'} - $timeticks)/100);
	$timeticks = $res->{'1.3.6.1.2.1.1.3.0'};
	
	push(@out, time);
	
	if ( $result == 1 and $timediff != 0 and $restart != 1 ) {
		
		if ($ARGV[1] == 1) {    
			$timediff = round($timediff);
		}
		
		foreach $value (1 .. ($#list)) {
			if (($types->{"$list[$value]"}) == 128) {   
				push(@out, "| N/A");
			}

			elsif (($types->{"$list[$value]"}) == 65) {    
				$newvalue = $res->{"$list[$value]"};
				
				if ($oid{"$list[$value]"} > $newvalue) {
				
					$rate = sprintf("%0d",(((2**32) + ($newvalue) - ($oid{"$list[$value]"}))/$timediff));
					push (@out, "| $rate");
					$oid{"$list[$value]"} = $newvalue;
				}
				else {
					$rate = sprintf("%0d",(($newvalue - $oid{"$list[$value]"})/$timediff));
					push (@out, "| $rate");
					$oid{"$list[$value]"} = $newvalue;
				}
			}
			
			elsif (($types->{"$list[$value]"}) == 70) {    
			
				$newvalue = $res->{"$list[$value]"};
				
				if ($oid{"$list[$value]"} > $newvalue) {
					$rate = sprintf("%0d",(((2**64) + ($newvalue) - ($oid{"$list[$value]"}))/$timediff));
					push (@out, "| $rate");
					$oid{"$list[$value]"} = $newvalue;
				}
				else {
					$rate = sprintf("%0d",(($newvalue - $oid{"$list[$value]"})/$timediff));
					push (@out, "| $rate");
					$oid{"$list[$value]"} = $newvalue;
				}
			}
		}
		
		
		if ($loop > 1) {
			print "@out\n";
			$sample++;
		}
	}

	if ($restart) {
		push(@out, "| RESTART/REBOOT");
		print "@out\n";
		$restart = 0;
	}

	if ($result == 0) {
		push(@out, "| TIMEOUT, Ts=$timeout R=$retries");
		print "@out\n";
		$sample++;
	}
	
	@out = ();
	$loop++;
	
	if ($sample == $req_samples) {
		$session->close();
		exit;
	}
	
	$endtime = gettimeofday();

	$executiontime = $endtime - $starttime;
	my $k = ceil (($endtime - $starttime)/$freq );

	if ($executiontime < $freq) 
		{ $actual_sleep = ($starttime + $k*$freq) - $endtime; }
	else 
		{ $actual_sleep = ($starttime+($k+1)*$freq) - $endtime; }

	$sleeptime = $actual_sleep * 1000000000;  
	nanosleep($sleeptime);

	
	$session->close();
}
