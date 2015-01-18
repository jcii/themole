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
#sub POE::Kernel::TRACE_PROFILE() { 1 }
#sub POE::Kernel::TRACE_SESSIONS() { 1 }
#sub POE::Kernel::TRACE_REFCNT() { 1 }
sub Mole::MSG_DEBUG { 3 }

use YAML;
use POE;
use Mole;
use Mole::Message;
use Mole::Client;
 
my $debug = 0;
my $i;

my @ro_ports=(["password1",    161]);


Mole::Client->spawn;
Mole->spawn(\@ro_ports);
##
## Build message to send to Mole
##
my $msg;
my @array;
$msg = Mole::Message->new;
##
## Pack all IPs into a single message
##
while (my $ip = <>) {
   chomp $ip;
   push(@array, $ip);
}
$msg->dstargs( {ips => \@array} ); 
##
## Tell the Mole to process message
##
$poe_kernel->post('Mole', 'process', $msg);
$poe_kernel->run();
exit 0;
