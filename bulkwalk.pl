#!/usr/bin/perl -w
use Data::Dumper;
use strict;
use Net::SNMP;
my ($session, $error) = Net::SNMP->session(
                 -hostname => '10.145.107.1',
                 -port     => 161,
                 -community=> 'password1',
                 -debug    => 0x10,
                 -version  => 2
              );

if (!defined($session)) {
   printf("ERROR: %s.\n", $error);
   exit 1;
}

my $result = $session->get_request( -varbindlist => ['1.3.6.1.2.1.4.22.1.2.13.10.145.107.227']);
#my $result = $session->get_bulk_request(
#   -callback       => [\&table_cb, {}],
#   -maxrepetitions => 10,
#   -varbindlist    => ['1.3.6.1.2.1.4.22']
#);

#&snmp_dispatcher();
my $key;
foreach $key (keys(%{$result})) {
   printf("%s\t\"%s\"\n", $key, $result->{$key});
}
print Dumper($result, $session);
print $session->error . "\n";
$session->close;
