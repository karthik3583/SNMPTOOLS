#!/usr/bin/perl

use strict;
use warnings;

my $DEBUG = $ENV{'DEBUG'} // 0;

use Net::SNMP;
use Time::HiRes qw(gettimeofday nanosleep time);
use Math::Round;
use POSIX qw(ceil fmod);

die "Usage: $0 ip:port:community freq count OID [...]\n" unless defined($ARGV[3]);

my ($IP, $PORT, $COMMUNITY) = split /:/, $ARGV[0];
my $FREQ = $ARGV[1] * 1000000000;
my $NUM_SAMPLES = $ARGV[2];

my $SAMPLE = 0;
my $TIMEOUT = 10;
my @LIST;
my $timeticks = 0;

@LIST = map { $ARGV[$_] } (3 .. $#ARGV);

# Ensure all OIDs have a leading dot
for (my $i = 0; $i <= $#LIST; $i++) {
    $LIST[$i] = '.' . $LIST[$i] unless ($LIST[$i] =~ /^\..*/);
}

my @previous;
my @current;
my $snmpUptime;
my $lastRequestTime;
my $timeoutR = 0;

# Main loop
while (1) {
    last if ($NUM_SAMPLES != -1 && $SAMPLE >= $NUM_SAMPLES + 1);
    $SAMPLE++;

    my $snmpResponse = connect_to_snmp();

    my @out = ();
    push @out, time();

    # Handle SNMP timeout
    if ($snmpResponse == -1) {
        push @out, "TIMEOUT, Ts=$TIMEOUT R=$timeoutR";
        $timeoutR++;
        print join(' | ', @out), "\n";
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
        push @current, $snmpResponse->{$oid};
    }

    # Handle first request
    if (scalar @previous == 0) {
        $snmpUptime = $oid_snmpUptime;
        $lastRequestTime = $oid_snmpUptime;
        @previous = @current;
        next;
    }

    if ($oid_snmpUptime < $timeticks) {
        push @out, "RESTART/REBOOT";
        @previous = ();
        @current = ();
        print join(' | ', @out), "\n";
        next;
    }

    my $timeDiff = ($oid_snmpUptime - $timeticks) / 100;
    $timeticks = $oid_snmpUptime;

    if ($timeDiff != 0) {
        my $inter_TS = round($timeDiff);

        if ($ARGV[1] == 2) {
            $inter_TS = $timeDiff;
        }

        for (my $i = 0; $i <= $#current; $i++) {
            my $rate;
            if (($current[$i] eq "Incorrect OID Entered") or (int($inter_TS) == 0)) {
                $rate = "N/A";
            } else {
                if ($current[$i] < $previous[$i]) {
                    if ($current[$i] <= (2**32 - 1)) {
                        $rate = sprintf("%d", (2**32 + $current[$i] - $previous[$i]) / $inter_TS);
                    } else {
                        $rate = sprintf("%d", (2**64 + ($current[$i] - $previous[$i])) / $inter_TS);
                    }
                } else {
                    $rate = sprintf("%d", ($current[$i] - $previous[$i]) / $inter_TS);
                }
                push @out, $rate;
            }
            printf("DEBUG[%d] -> %d,%d:%d - $rate\n", $i, $current[$i], $previous[$i], $inter_TS) if $DEBUG;
        }

        print join(' | ', @out), "\n";
        @previous = @current;
    }

    nanosleep($FREQ);
}

sub connect_to_snmp {
    my ($session, $error) = Net::SNMP->session(
        -hostname  => $IP,
        -port      => $PORT,
        -community => $COMMUNITY,
        -version   => "2c",
        -translate => [-timeticks => 0x0],
    );

    die "ERROR: $error" if (!defined $session);

    $session->timeout($TIMEOUT);

    my @oids = ('1.3.6.1.2.1.1.3.0', '1.3.6.1.4.1.4171.50.1', @LIST);
    my $snmpResponse = $session->get_request(-varbindlist => \@LIST);

    return -1 if (!defined $snmpResponse);

    $session->close();
    return $snmpResponse;
}
