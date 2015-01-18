package Mole;
################################################################################
##
## Mole.pm
##
##
## $Author: themole $
## $Revision: 1.2 $
## $Date: 2004/04/19 17:14:26 $
##
################################################################################
use Mole::MDC;
@ISA = qw(Mole::MDC);
use strict;
use warnings;
use Carp;
use POE;
use Mole::RDBMS;
use Mole::Record;
use Mole::Message;
use Mole::Digger;
my $debug = 1;


################################################################################
## Class Variables
##
our $ALIAS= 'Mole';
################################################################################


sub spawn { 
   my $package = shift;
   my $self = $package->new(@_);
   POE::Session->create( object_states => [ $self => [qw( _start _child _stop execute process )] ]);
}

sub new { 
   my $package = shift;
   my $roports = shift;
   my $self    = {};
   bless $self, $package;
   $self->{ipreg}   = {};
   $self->{macreg}  = {};
   $self->{roports} = $roports;
   return $self;
}

sub _start {
   my ($kernel, $self, $session) = @_[KERNEL, OBJECT, SESSION];
   $kernel->alias_set($ALIAS);
   printf("Starting ---%s--- ID=%s\n", , ref($self), $session->ID) if $debug;
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
   printf("%s::_stop ID=%s\n", ref($self), $session->ID) if $debug;
}

sub registry {
   my $self  = shift;
   my $entry = shift;
   ##
   ##
   ##
   if (ref($entry) eq 'HASH') {

      return;
   }
   ##
   ##
   ##
   unless (ref($entry)) {
      return $self->_regget($entry);
   }
}

sub _regget {
   my $self  = shift;
   my $entry = shift;
 
   if ($entry =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) {
      my $ipreg = $self->{ipreg};
      return $ipreg->{$entry} if defined($ipreg->{$entry});
   }
   return undef;
}

sub register {
   my $self = shift;

}

################################################################################
sub execute { 
   my ($kernel, $self, $sess) = @_[KERNEL, OBJECT, SESSION];
   printf("---- %s::execute ID=%s ------------------\n", ref($self), $sess->ID) if $debug;
   my $msg;
   ##
   ## Schedule re-entrant event
   ##
   $kernel->delay_set('execute', 2);
}

################################################################################
sub process {
   my ($kernel, $self, $sess, $sender, $msg) = @_[KERNEL, OBJECT, SESSION, SENDER, ARG0];
   printf("%s::process SNDR=%s TYPE=%s\n", ref($self), $sender, ref($msg)) if $debug;
   ##
   ## Message type 'Discovered IPs'
   ##
   my $ips = $msg->dstargs('ips');
   foreach my $ip (@$ips) {
      unless ($self->registry($ip)) {
         printf("%s::process Spawning Digger for %s\n", ref($self), $ip) if $debug;
         my $record = Mole::Record->new;
         my $digger = Mole::Digger->spawn($ip, $self->{roports});
         $record->digger($digger);
         $self->register( {$ip => $record} );
      }
   }
   ##
   ## Message type 'Discovered Interfaces'
   ##

   ##
   ## Message type 'Discovered MACs'
   ##
}


1;
