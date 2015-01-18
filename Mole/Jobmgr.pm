package Mole::Jobmgr;
use Mole::MDC;
@ISA = qw(Mole::MDC);
use strict;
use Mole::Datamgr;
my $debug = 0;
################################################################################
##
## Jobmgr.pm
##
## Jobmgr is a queue for synchronous scheduling of actions within a Digger. 
## The Digger class, an asynchronous POE session, will get jobs from the Jobmgr
## to process (create new sessions if necessary).
##
## The Jobs are added and removed by Bhvrmgr when Behavior patterns change. 
##
## Jobs are created by Job::Proto prototypes. Prototypes are classes that 
## contain initial values and job-dependent arguments.
##
## $Author: themole $
## $Revision: 1.5 $
## $Date: 2004/04/07 02:05:15 $
##                 
##                 
################################################################################

sub new { 
   my $package = shift;
   my $digger = shift;
   my $self = {};
   $self->{digger} = $digger;
   $self->{queue} = []; 		# FIFO Array
   $self->{list}  = [];			# Array of running POE sessions
   return bless $self, $package;
}
################################################################################
##
## add($msg) : Job::msg
##  
## TODO Refactor comments
##  
## Add expects a Job::Proto reference as an argument. 
## Attributes of proto are used for job management. 
##    The $proto->{job} attribute contains the job object. 
## Digger will call $job->spawn to create POE::Session if not already existant.
## $self->{list} contains # of bhvrs that 'added' the Job (KEY = $name)
##
################################################################################
sub add { 
   my $self = shift;
   my $msg = shift;			# Prototype reference(s)
   my $queue = $self->{queue};		# Jobs to be executed
   my $list  = $self->{list};		# Executed Jobs
   my $digger= $self->digger;
   ##
   ## Cycle through each prototype reference and determine if job already
   ## exists.
   ##
   my $cmpval;
   foreach my $ref ($self->_list) {
      $cmpval = $ref->compare($msg);
      if (defined($cmpval)) {
         $self->refincr($msg);
         printf("%s::add+INCR TYPE=%s CMPVAL=%s\n", ref($self), ref($msg), $cmpval) if $debug;
         return;
      }
   }
   ##
   ## Job doesn't exist, add spawn cmd to queue
   ##
   printf("%s::add TYPE=%s NAME=%s\n", ref($self), ref($msg)) if $debug;
   $self->_push_queue($msg);
   ##
   ## Increment refcount
   ##
   $self->refincr($msg);
}

sub refincr {
   my $self = shift;
   my $msg  = shift;
   my $refcnt = $msg->dstargs('refcnt');
   $refcnt++;
   $msg->dstargs({refcnt => $refcnt});
   return $refcnt;
}

sub refdecr {
   my $self = shift;
   my $msg  = shift;
   my $refcnt = $msg->dstargs('refcnt');
   $refcnt--;
   $msg->dstargs({refcnt => $refcnt});
   return $refcnt;
}

################################################################################
sub remove {
   my $self = shift;
   my $msg = shift || return;
   my $queue = $self->{queue};
   my $list  = $self->{list};
   printf("%s::remove CALLER=%s\n", ref($self), caller(1)) if $debug;
   ##
   ## Decrement behavior reference count and delete if its
   ## not referenced anymore
   ##
   my $cmpval;
   foreach my $ref ($self->_list) {
      $cmpval = $ref->compare($msg);
      if (defined($cmpval)) {
         $self->refdecr($ref);
      }
      ##
      ## TODO Delete unreferences messages
      ##
   }
}

sub _push_queue {
   my $self = shift;
   my $msg  = shift;
   my $queue = $self->{queue};
   #my $job = $proto->job;
   ##
   ## 
   ##
   printf("%s::_push_enqueue TYPE=%s NAME=%s\n", ref($self), ref($msg), $msg->name) if $debug;
   push(@$queue, $msg);
}

################################################################################
##
## List of Messages sent
##
sub _list {
   my $self = shift;
   my $msg = shift;
   my $list = $self->{list};
   foreach my $ref (@$list) {
      printf("%s::_list TYPE=%s \n", ref($self), ref($ref)) if $debug;
   }
   return @$list;
}

sub list {
   my $self = shift;
   my $list = $self->{list};
   

}
################################################################################
sub get {
   my $self = shift;
   my $queue= $self->{queue};
   my $list = $self->{list};
   my $msg = shift(@$queue);
   push(@$list, $msg) if defined($msg);
   if ($debug) {
      if (defined($msg)) {
         printf("%s::get CNT=%s TYPE=%s\n", ref($self), $#$queue+1, ref($msg));
      } else {
         printf("%s::get QUEUE EMPTY\n", ref($self)) unless defined($msg);
      }
   }
   return $msg;
}

1;
