#!/usr/bin/perl

use warnings;



use NetSNMP::agent (':all');

use NetSNMP::ASN qw(:all);

use NetSNMP::OID;

use Time::HiRes qw(time);

use POSIX       qw( strftime );

use Math::Round;



$| = 1; #disable the output buffering

# 01 October 2018:

my $SINCE = 1538352000;



sub hello_handler

{

	my ($handler, $registration_info, $request_info, $requests) = @_;

	my $request;

	my $CURR_TIME = Time::HiRes::time();
	

    my $microsecs = int($CURR_TIME*1000000);

	for($request = $requests; $request; $request = $request->next()) 

	{

		my $oid = $request->getOID();

		my @oidarray = split/[.]/,$oid;

		my $lastOIDindex = $oidarray[-1];

		if ($request_info->getMode() == MODE_GET)

		{

			if ($oid >= new NetSNMP::OID("1.3.6.1.4.1.4171.40.1") &&

				$oid < new NetSNMP::OID("1.3.6.1.4.1.4171.50.1"))

			{

				open(my $cnf, '<', "/tmp/A1/counters.conf");

				my %data;

				while(<$cnf>) {

					chomp;

					my ($counter,$value) = split(',',$_);

					$data{$counter} = int $value;

				}

				

				if (defined $data{$lastOIDindex}) 

				{

					my $value = $data{$lastOIDindex};

					my $result = $value * $CURR_TIME;

					$request->setValue(ASN_COUNTER64, int $result);	

				}

				else 

				{

					$request->setValue(ASN_OCTET_STR, "Incorrect OID Entered");

				}

			}

			if ($oid == new NetSNMP::OID("1.3.6.1.4.1.4171.50.1"))

            {

                $request->setValue(ASN_COUNTER64, $microsecs);

            }

			if ($oid == new NetSNMP::OID("1.3.6.1.4.1.4171.50.2")) {

				# parse config file

				open(my $cnf, '<', "/tmp/A1/counters.conf") or die "File not found";

				my $counter = 0;

				while(<$cnf>) { 

					$counter++ if (length($_) > 0  && $_ !~ /^#.*/);

				}

				close $cnf;

				$request->setValue(ASN_INTEGER,$counter);

			}

			if ($oid == new NetSNMP::OID("1.3.6.1.4.1.4171.50.3"))

            {

                $request->setValue(ASN_OPAQUE,100.500);

            }

		}

	}

}



my $agent = new NetSNMP::agent();

$agent->register("karthik", "1.3.6.1.4.1.4171", \&hello_handler);



