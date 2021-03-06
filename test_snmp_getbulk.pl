#!/usr/bin/perl
use strict;
use warnings;
use Carp;
sub POE::Kernel::ASSERT_DEFAULT () { 1 }
#sub POE::Kernel::TRACE_DEFAULT  () { 1 }
sub POE::Kernel::TRACE_PROFILE() { 1 }
use POE;
use Net::SNMP;
use Mole::Snmp;
my $debug = 0;
my $i;
#my $branch = "1.3.6.1.2.1.2.2"; 	# interfaces table
my $branch = "1.3.6.1.2.1.1"; 		# system info table
#my $branch = ".1.3.6.1.2.1.3.1.1.2";	# Address Translation (ARP) table
Mole::Snmp->spawn();
POE::Session->create(
   inline_states => { _start => sub {
                         my ($kernel, $session) = @_[KERNEL, SESSION];
                         printf("TEST_SNMP KERNEL: %s\n", $kernel) if $debug;
                         printf("TEST_SNMP SESSION: %s\n", $session) if $debug;
                         printf("TEST_SNMP SESSION ID: %s\n", $session->ID) if $debug;
                         while (<>) {
                            chomp $_;
                            my $postback = $session->postback('handler');
                            $poe_kernel->post("SNMP", "getbulk", $postback, $_, $branch, "public");
                         }
                      },
                      _stop  => sub { 
                         print "Stopping TEST_SNMP\n";
                         printf("TEST_SNMP Line Count %s\n", $i);
                      },
                      handler=> sub {
                         my ($kernel, $aryref) = @_[KERNEL, ARG1];
                         my $varlist = shift @$aryref;
                         my $mgmtip = shift @$aryref;
                         my $RO = shift @$aryref;
                         printf("TEST_SNMP HANDLER COUNT: %s\n", scalar keys (%{$varlist})) if $debug;
                         foreach my $oid  (Net::SNMP::oid_lex_sort(keys(%{$varlist}))) {
                            $i++;
                            printf("%s\t%s\t%s = %s\n", $mgmtip, $RO, $oid, $varlist->{$oid}) if $debug;
                         } 

                      }
                    },
);

$poe_kernel->run();
exit 0;
