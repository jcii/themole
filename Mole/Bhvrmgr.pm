package Mole::Bhvrmgr;
################################################################################
##
## Mole::Bhvrmgr.pm
##
## Bhvrmgr is responsible for creating & removing jobs based on behavior
## patterns. Behavior patterns represent real-world things, like Switches,
## Routers, SSM agents, and printers.
## 
## Datamgr will request the addition/removal of a behavior. At creation
## time a behavior of 'unknown' is assumed if none is suppied with the
## constructor.
##
##
## $Author: u169809 $
## $Revision: 1.9 $
## $Date: 2004/06/15 14:35:28 $
##
################################################################################
use Mole::MDC;
@ISA = qw(Mole::MDC);
use strict;
use warnings;
use Carp;
#use Mole::Bhvr;
use Mole::Jobmgr;
use Mole::Bhvr::Unknown;
use Mole::Bhvr::CRouter;
use Mole::Bhvr::CBridge;
use Mole::Bhvr::SSM;
my $debug = 0;
##
## Behavior prototypes
##
## The values of behavior prototypes must be defined in the Job prototypes
## and handled by Jobmgr.pm
## 
## The key of the behavior becomes the name
##
my %behaviors = ( unknown => qw( Mole::Bhvr::Unknown ),
                  #SSM     => [ qw(Mole::Job::Proto::Systable nbtstat agentInfo) ],
                  SSM     => qw( Mole::Bhvr::SSM ),
                  router  => qw( Mole::Bhvr::CRouter ), 
                  bridge  => qw( Mole::Bhvr::CBridge ), 
                  other   => [ qw() ]
                );

################################################################################
##
## new($digger, [$behavior])
## 
## Behavior managers may be called with an initial behavior. If no behavior is 
## passed then unknown is assumed.
##
sub new { 
   my $package = shift;
   my $self = {};
   bless $self, $package;
   $self->{bhvrs} = {};
   $self->{disco} = 0;
   $self->{discotm} = 0;
   $self->{discotmout} = 300;
   $self->{digger} = shift;
   
   ##
   ## Use provided behavior or default to unknown.
   ##
   if (@_)  { $self->add(@_); }
   return $self;
}

################################################################################
##
## add($name)
##
## Add a $name'd behavior to a digger. 
## Must be a valid behavior name defined in the %behaviors hash. 
## Behaviors can only be added once. 
## The jobmgr keeps a count of the number of job prototypes from the behaviors
## jobs are removed when the count reaches zero.
##
sub add {
   my $self = shift;
   my $name = shift;
   my $bhvrs = $self->{bhvrs};
   my $digger = $self->{digger};
   my $jobmgr= $digger->jobmgr;
   ## 
   ## Skip behavior prototype of it already exists
   ## If the behavior prototype is defined, add to list
   ## 
   if (defined ($behaviors{$name}) && not defined($bhvrs->{$name})) { 
      ##
      ## If we're adding a behavior, remove the unknown behavior
      ##
      if ($name ne 'unknown' && defined($bhvrs->{'unknown'}) ) {
         $self->remove('unknown');
         $self->discovery(0);
         printf("%s::add\tNAME:%s\n", ref($self), $name) if $debug;
      }
      ##
      ## $behavior{} maps a name to a method/package
      ## and calls the method constructor
      ## 
      my $bhvr = $behaviors{$name}->new($self);
      ##
      ## TODO Need method call here
      ##
      $bhvrs->{$name} = $bhvr;
      ##
      ## Get jobs assigned from behavior prototype
      ##
      #foreach my $msg ($bhvr->jobs) {
         #$msg->dstargs( {mgmtip => $digger->mgmtip} );
         #$jobmgr->add($msg);
         #$self->debug;
      #}
      $bhvr->evaluate;
   }
   return $bhvrs->{$name};
}

################################################################################
##
## remove($name)
##
sub remove  { 
   my $self = shift;
   my $name = shift;
   my $bhvrs = $self->{bhvrs};
   my $digger = $self->digger;
   my $jobmgr= $digger->jobmgr;
   ##
   ## If the behavior exists, remove its jobs
   ##
   if (defined $bhvrs->{$name}) { 
      ##
      ## Cycle through jobs associated with behavior
      ##
      foreach my $prototype (values(%{ $bhvrs->{$name} })) {
         $jobmgr->remove($prototype);
      }
      ##
      ## Delete behavior instance
      ##
      printf("%s::remove\tNAME=%s\n", ref($self), $name) if $debug;
      delete $bhvrs->{$name};
   }
}

################################################################################
sub list {
   my $self = shift;
   return keys %{$self->{bhvrs}};
}

################################################################################
sub get {
   my $self = shift;
   my $name = shift || return undef;
   my $bhvrs = $self->{bhvrs};
   return $bhvrs->{$name};
}

################################################################################
sub state {
   my $self = shift;
   my @bhvrlist = $self->list;
   #printf("%s::list\tLIST=%s\n", ref($self), $#bhvrlist ) if $debug;
   if ($self->discovery) {
      return 'discovery';
   } else {
      if ($#bhvrlist == -1 || $bhvrlist[0] eq 'unknown' ) {     # No definedlbehaviors
         return 'unknown';
      } else {
         return 'known';
      }
   }
}
                                                                                                                                               
################################################################################
sub evaluate {
   my $self = shift;
   my $list = $self->list;
   my $bhvr;
   ##
   ## Run through known behaviors and let them do their thing
   ##
   foreach my $name ($self->list) { 
      $bhvr = $self->get($name);
      $bhvr->evaluate;
   }
   #printf("%s::evaluate\tSTATE:%s\tDISCO=%s\n", ref($self), $self->state, $self->discovery ) if $debug;
   ##
   ## Am I known? If not add unknown behavior.
   ##
   if ($self->state eq 'unknown' && not $self->discovery) {
      $self->add('unknown');
      $self->discovery(1);
   }
   ## 
   ## Record discovery timing statistics 
   ## If status is discovery and time has exceeded 5 minutes, flip disco bit
   ## 
   if ($self->state eq 'discovery' && ($self->{discotm} < time - $self->{discotmout})) { 
      $self->discovery(0);
   }
}

################################################################################
sub discovery {
   my $self = shift;
   my $val = shift;
   if (defined($val)) {
      if ($val eq '1') { 
         $self->{disco} = 1; 
         $self->{discotm} = time;
      }
      if ($val eq '0') { $self->{disco} = 0; }
      printf("%s::discovery\tVAL=%s\n", ref($self), $self->{disco} ) if $debug;
      return $self->{disco};
   }
   return $self->{discotm};
}
1;
