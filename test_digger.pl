#!/usr/bin/perl
use strict;
use warnings;
use Carp;
sub POE::Kernel::ASSERT_DEFAULT () { 1 }
#sub POE::Kernel::ASSERT_DATA () { 1 }
sub POE::Kernel::ASSERT_EVENTS () { 1 }
#sub POE::Kernel::ASSERT_FILES () { 1 }
#sub POE::Kernel::ASSERT_RETVALS () { 1 }
#sub POE::Kernel::ASSERT_USAGE () { 1 }
#sub POE::Kernel::TRACE_DEFAULT() { 1 }
#sub POE::Kernel::TRACE_EVENTS() { 1 }
sub POE::Kernel::TRACE_PROFILE() { 1 }
#sub POE::Kernel::TRACE_SESSIONS() { 1 }
#sub POE::Kernel::TRACE_REFCNT() { 1 }

use POE;
use Mole::Digger;
use Mole::Client;
my $debug = 0;
my $i;



#my $branch = "1.3.6.1.2.1.2.2"; 	# interfaces table
#my $branch = "1.3.6.1.2.1.1"; 		# system info table
my $branch = ".1.3.6.1.2.1.3.1.1.2";	# Address Translation (ARP) table
my @ro_ports=(
           ["password1", 161],
           ["password2", 161]
         );

Mole::Client->spawn();
sleep 1;
POE::Session->create(
   inline_states => { _start => sub {
                         my ($kernel, $session) = @_[KERNEL, SESSION];
                         $kernel->alias_set("TEST HARNESS");
                         printf("Starting TEST_HARNESS ID=%s\n", $session->ID);
                         my $digger;
                         while (<>) {
                            chomp $_;
                            $digger = Mole::Digger->spawn($_, \@ro_ports);
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
                         my ($kernel) = $_[KERNEL];
                         printf("HARNESS::handler\n") if $debug;
                      }
                    },
);

$poe_kernel->run();
exit 0;
