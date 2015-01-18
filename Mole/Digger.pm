package Mole::Digger;
################################################################################
##
## Mole::Digger.pm
##
## This POE-based Module watches SNMP-based devices. It "digs" for changes in
## MIB-based tables and responds to changes based on lookup tables.
##
##
## $Author: themole $
## $Revision: 1.11 $
## $Date: 2004/04/19 17:13:30 $
##
################################################################################
use Mole::MDC;
@ISA = qw(Mole::MDC);
use strict;
use warnings;
use Carp;
use POE;
use Net::SNMP;
#use Mole::Job::SNMP;
use Mole::Bhvrmgr;
use Mole::Datamgr;
my $debug = 0;

sub spawn { 
   my $package = shift;
   my $self = $package->new(@_);
   POE::Session->create( object_states => [ $self => [qw( _start _child _stop execute handle )] ]);
}

sub new { 
   my $package = shift;
   my $self    = {};
   bless $self, $package;
   $self->{digger} = $self;
   $self->{mgmtip} = shift;
   ##
   ## TODO RO/ports for SNMP should be pulled from top-level
   ## MOLE class, not hard-coded.
   ##
   $self->{datamgr}= Mole::Datamgr->new($self, shift);		# Initial roports passed to datamgr
   ##
   ## TODO Need to check cached data/datamgr. 
   ## TODO 'default' behavior should be chosen by
   ## data state, not hard-coded.
   ##
   $self->{bhvrmgr}= Mole::Bhvrmgr->new($self); 
   ##
   ##
   ##
   $self->{jobmgr} = Mole::Jobmgr->new($self);
   return $self;
}

sub _start {
   my ($kernel, $self, $session) = @_[KERNEL, OBJECT, SESSION];
   $self->{alias} = "DIGGER-".$self->mgmtip;
   $kernel->alias_set($self->{alias});
   printf("Starting %s-%s ID=%s\n", , ref($self), $self->mgmtip, $session->ID) if $debug;
   ##
   ## TODO Initiate NetBIOS, other initiation processes
   ## NetBIOS, nmap, DNS, proxy, etc.
   ##
   $kernel->yield('execute');
}

sub _child {
   my ($kernel, $self, $sess, $cdstate, $child) = @_[KERNEL, OBJECT, SESSION, ARG0, ARG1];
   printf("%s::_child ID=%s %s %s\n", ref($self), $sess->ID, $cdstate, $child->ID) if $debug;
   if ($cdstate eq 'create') {
   }
}

sub _stop {
   my ($kernel, $self, $session) = @_[KERNEL, OBJECT, SESSION];
   printf("%s::_stop %s ID=%s\n", ref($self), $self->mgmtip, $session->ID) if $debug;
}

sub alias {
   my $self = shift;
   return $self->{alias};
}

sub mgmtip {
   my $self = shift;
   return $self->{mgmtip};
}
################################################################################
sub execute { 
   my ($kernel, $self, $sess) = @_[KERNEL, OBJECT, SESSION];
   my $jobmgr = $self->jobmgr;
   my $bhvrmgr= $self->bhvrmgr;
   my $datamgr= $self->datamgr;
   my $msg;
   printf("---- %s::execute ID=%s --------------\n", ref($self), $sess->ID) if $debug;
   ##
   ## Load / munge data
   ##
   $datamgr->evaluate;
   ##
   ## Evaluate Behaviors
   ## Bhvrmgr knows the behaviors associated with the Digger.
   ## Behaviors make decisions based on current data.
   ##
   $bhvrmgr->evaluate;
   ##
   ## Get Mole::Message's from jobmgr for processing
   ##
   while ($msg = $jobmgr->get) {
      ##
      ## Tell the message who its parent is and the Event to post to
      ## to return data.
      ##
      $msg->orgsess($sess->ID);
      $msg->orgevent('handle');
      printf("%s::execute ACTION=%s MSG=%s\n", ref($self), $msg->action, ref($msg)) if $debug;
      $msg->debug(ref($self).'::execute') if $debug;
      ##
      ## Post Mole::Message to Destination event
      ##
      if ($msg->action eq $Mole::Client::ALIAS) {
         $msg->dstargs( {mgmtip => $self->mgmtip} );
         $kernel->post($Mole::Client::ALIAS, 'send', $msg);
         next;
      }
      ##
      if ($msg->action eq $Mole::RDBMS::ALIAS) {
         printf("%s::execute RDBMS EVENT=%s MSG=%s\n", ref($self), $msg->dstevent, ref($msg)) if $debug;
         $kernel->post($Mole::RDBMS::ALIAS, $msg->dstevent, $msg);
         next;
      }
      ##
      if ($msg->action eq $MOLE::ALIAS) {
         $kernel->post($Mole::ALIAS, 'process', $msg);
         next;
         
      }
      ##
   }
   ##
   ## Schedule re-entrant event
   ##
   $kernel->delay_set('execute', 2);
}

################################################################################
sub handle {
   my ($kernel, $self, $sess, $sender, $msg) = @_[KERNEL, OBJECT, SESSION, SENDER, ARG0];
   my $varlist = $msg->dstargs('data');
   #printf("%s::handle SNDR=%s TYPE=%s\n", ref($self), $sender, ref($varlist)) if $debug;
   my $datamgr= $self->datamgr;
   $msg->debug(ref($self).'::handle') if $debug;
   $datamgr->handle($msg);
}


1;
