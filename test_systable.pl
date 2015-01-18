#!/usr/bin/perl
use strict;
use warnings;
use Carp;
#sub POE::Kernel::ASSERT_DEFAULT () { 1 }
#sub POE::Kernel::ASSERT_DATA () { 1 }
#sub POE::Kernel::ASSERT_EVENTS () { 1 }
#sub POE::Kernel::ASSERT_FILES () { 1 }
#sub POE::Kernel::ASSERT_RETVALS () { 1 }
#sub POE::Kernel::ASSERT_USAGE () { 1 }
#sub POE::Kernel::ASSERT_STATES () { 1 }
#sub POE::Kernel::TRACE_EVENTS() { 1 }
sub POE::Kernel::TRACE_PROFILE() { 1 }
#sub POE::Kernel::TRACE_SESSIONS() { 1 }
#sub POE::Kernel::TRACE_REFCNT() { 1 }
use POE;
use Net::SNMP;
use Mole::Job;
use Mole::Snmp;
my $debug = 1;
my $i;
#my $branch = "1.3.6.1.2.1.2.2"; 	# interfaces table
my $branch = "1.3.6.1.2.1.1"; 		# system info table
#my $branch = ".1.3.6.1.2.1.3.1.1.2";	# Address Translation (ARP) table
Mole::Snmp->spawn();
POE::Session->create(
   inline_states => { _start => sub {
                         my ($kernel, $session) = @_[KERNEL, SESSION];
                         $kernel->alias_set("TEST HARNESS");
                         printf("Starting TEST_HARNESS ID=%s\n", $session->ID);
                         while (<>) {
                            chomp $_;
                            Mole::Job::Systable->spawn(name      => "sysTable",
                                                       longevity => 30,
                                                       age       => 0,
                                                       oid       =>  $branch,
                                                       port      => 161,
                                                       rostr     => "password",
                                                       ip        => $_,
                                                       parent   => $session,
                                                       #handler  => $session->postback('handler'),
                                                       prnt_hndl=> "handler",
                                                      );

                         }
                      },
                      _parent => sub {
                         print "HARNESS::_parent\n";
                      },
                      _child => sub {
                         my ($kernel, $cdstate, $child) = @_[KERNEL, ARG0, ARG1];
                         printf("HARNESS::_child %s %s\n", $cdstate, $child->ID) if $debug;
                      },
                      _stop  => sub { 
                         my ($kernel, $session) = @_[KERNEL, SESSION];
                         printf("Stopping TEST_HARNESS ID=%s\n", $session->ID);
                      },
                      handler=> sub {
                         #print "HARNESS::handler\n";
                         my ($kernel, $type, $varlist) = @_[KERNEL, ARG0, ARG1];
                         foreach my $oid (Net::SNMP::oid_lex_sort(keys(%{$varlist}))) {
                            printf("HARNESS::handler %s %s = %s\n", $type, $oid, $varlist->{$oid});
                         }
                      }
                    },
);

$poe_kernel->run();
exit 0;
