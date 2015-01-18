#!/usr/bin/perl
package Mole::Message;
use warnings;
use strict;
use Mole::Message::Systable;
use Mole::Message::Attable;
use Mole::Message::Iftable;
use Mole::Message::Fdbtable;
use Mole::Message::Vtptable;
use Mole::Message::Hsrptable;
use Mole::Message::Ipaddrtable;
use Mole::Message::NH::Agent;
use Mole::Message::NH::srLogMon;
use Mole::Message::RDBMS;
use Data::Dumper;

my $debug = 0;
################################################################################
##
## TODO Ideas for message pieces
## - return timing
## - store n forward behavior
## - timezone information
## - time alive
## - hop information (if routed .. HAHAHA Not in this language )
## - PERSISTANT / REPLAY MESSAGE!
##
################################################################################
sub new {
   my $package = shift;
   my $self = bless {}, $package;
   #$self->{mid}      = undef ; #&main::getmid;		# Message ID
   $self->{orgip}    = undef;
   $self->{orgsess}  = undef;
   $self->{orgevent} = undef;
   $self->{dstip}    = undef;
   $self->{dstsess}  = undef;
   $self->{dstevent} = undef;
   $self->{dstargs}  = undef;
   $self->{action}   = undef;
   return $self;
}

sub mid {
   my $self = shift;
   my $val = shift;
   return $self->{mid} unless defined($val);
   $self->{mid} = $val;
}
sub orgip {
   my $self = shift;
   my $val = shift;
   return $self->{orgip} unless defined($val);
   $self->{orgip} = $val;
}
sub orgevent{
   my $self = shift;
   my $val = shift;
   return $self->{orgevent} unless defined($val);
   $self->{orgevent} = $val;
}
sub orgsess {
   my $self = shift;
   my $val = shift;
   return $self->{orgsess} unless defined($val);
   $self->{orgsess} = $val;
}

sub dstip {
   my $self = shift;
   my $val = shift; 
   return $self->{dstip} unless defined($val);
   $self->{dstip} = $val;
}
sub dstsess {
   my $self = shift;
   my $val = shift;
   return $self->{dstsess} unless defined($val);
   $self->{dstsess} = $val;
}

sub dstevent {
   my $self = shift;
   my $val = shift;
   return $self->{dstevent} unless defined($val);
   $self->{dstevent} = $val;
}

sub dstargs {
   my $self = shift;
   my $ref = shift;
   unless (defined($ref)) { return $self->{dstargs};}
   unless (ref($ref)) { return $self->{dstargs}->{$ref}; }
   foreach my $key (keys(%{$ref})) {
      $self->{dstargs}->{$key} = $ref->{$key};
   }
}

sub action {
   my $self = shift;
   my $val = shift;
   return $self->{action} unless defined($val);
   $self->{action} = $val;
}
##
## TODO probability of kludge high
##
sub compare {
   my $self = shift;
   my $ref  = shift;
   return undef unless defined($ref);;
   printf("%s::compare REF=%s\n", ref($self), ref($ref)) if $debug;
   ##
   ## Is the referant the same package?
   ##
   return undef unless ref($ref) eq ref($self);
   ##
   ## Does the referant have the same args?
   ##
   foreach my $key (sort keys %{$self}) {
      unless (ref $ref->{$key} ) {
         return undef unless defined($ref->{$key});
         return undef unless ($self->{$key} eq $ref->{$key});
         
      }

      if (ref $self->{$key}) {
         my $selfargs = $self->dstargs;
         my $refargs  = $ref->dstargs;
         foreach my $key (keys %{$selfargs} ) {
            return undef unless defined($refargs->{$key});
            return undef unless ($selfargs->{$key} eq $refargs->{$key});
         }
         foreach my $key (keys %{$refargs} ) {
            return undef unless defined($selfargs->{$key});
            return undef unless ($selfargs->{$key} eq $refargs->{$key});
         }
      }
   }
   return 1;
}


sub debug {
   my $self = shift;
   $self->{dbgstr}  = shift;
   $self->{dmplvl} = 1;
   my $str = $self->{dbgstr};
   my $lvl  = &Mole::MSG_DEBUG;
   my $cllr = caller(1);
   undef $Data::Dumper::Pad;
   $Data::Dumper::Pad = $str;
   ## 
   ##  Level 1 (default) of message debug
   ## 
   printf("%s::debug OBJECT=%s CALLER=%s\n", ref($self), $str, $cllr);
   return unless (defined($lvl) && $lvl > 1);
   ## 
   ##  Level 2 message debug (print org/dst information)
   ## 
   print Dumper($self);
   undef $Data::Dumper::Pad;
}
1;
