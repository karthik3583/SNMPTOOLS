#!/usr/bin/perl -w

use strict;
use warnings;
use Net::SNMP;
use Time::HiRes qw /gettimeofday nanosleep time/;
use Math::Round;
use POSIX qw /ceil fmod/;

my @list = ();
my %oid = ();  # Changed from an array to a hash to avoid conflicts
my $sample = 0;
my $loop = 1;
my $timeticks = 0;
my $result;
my $restart = 0;
my $timeout = 5;
my $retries = 0;
my $session;
my $error;
my $res;
my $types;
my @out;

my @agentdetails = split /:/, $ARGV[0];
my ($ip, $port, $community) = @agentdetails;
my $freq = 1 / $ARGV[1];
my $req_samples = $ARGV[2];

push(@list, "1.3.6.1.2.1.1.3.0");

foreach my $oid_index (3 .. $#ARGV) {
    push(@list, $ARGV[$oid_index]);
    $oid{"$ARGV[$oid_index]"} = 0;
}

my $starttime = gettimeofday();

while (1) {
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
        -translate => [-timeticks => 0x0]
    );

    if (defined($session)) {
        return 1;
    } else {
        return $error;
    }
}

sub get_Request {
    $res = $session->get_request(
        -varbindlist => \@list,
    );
    $types = $session->var_bind_types();

    if (defined($res)) {
        return 1;
    } else {
        return 0;
    }
}

sub set_Val {
    if ($result == 1 && $res->{'1.3.6.1.2.1.1.3.0'} < $timeticks) {
        $loop = 1;
        $timeticks = 0;
        $restart = 1;
    }
    my $timediff = (($res->{'1.3.6.1.2.1.1.3.0'} - $timeticks) / 100);
    $timeticks = $res->{'1.3.6.1.2.1.1.3.0'};

    push(@out, time);

    if ($result == 1 && $timediff != 0 && $restart != 1) {

        if ($ARGV[1] == 1) {
            $timediff = round($timediff);
        }

        foreach my $value (1 .. $#list) {
            if ($types->{$list[$value]} == 128) {
                push(@out, "| N/A");
            } elsif ($types->{$list[$value]} == 65) {
                my $newvalue = $res->{$list[$value]};
                my $rate;

                if ($oid{$list[$value]} > $newvalue) {
                    $rate = sprintf("%0d", (((2**32) + $newvalue - $oid{$list[$value]}) / $timediff));
                } else {
                    $rate = sprintf("%0d", (($newvalue - $oid{$list[$value]}) / $timediff));
                }
                push(@out, "| $rate");
                $oid{$list[$value]} = $newvalue;

            } elsif ($types->{$list[$value]} == 70) {
                my $newvalue = $res->{$list[$value]};
                my $rate;

                if ($oid{$list[$value]} > $newvalue) {
                    $rate = sprintf("%0d", (((2**64) + $newvalue - $oid{$list[$value]}) / $timediff));
                } else {
                    $rate = sprintf("%0d", (($newvalue - $oid{$list[$value]}) / $timediff));
                }
                push(@out, "| $rate");
                $oid{$list[$value]} = $newvalue;
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

    my $endtime = gettimeofday();
    my $executiontime = $endtime - $starttime;
    my $k = ceil(($endtime - $starttime) / $freq);

    my $actual_sleep;
    if ($executiontime < $freq) {
        $actual_sleep = ($starttime + $k * $freq) - $endtime;
    } else {
        $actual_sleep = ($starttime + ($k + 1) * $freq) - $endtime;
    }

    my $sleeptime = $actual_sleep * 1000000000;
    nanosleep($sleeptime);

    $session->close();
}
