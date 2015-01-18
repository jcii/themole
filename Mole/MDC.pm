################################################################################
##
## Mole::MDC.pm
##
## Mole Digger Component. A base class with common methods for all Digger
## components.
##
## $Author: themole $
## $Revision: 1.1 $
## $Date: 2004/04/12 03:14:44 $
##
################################################################################
package Mole::MDC;
use strict;

sub bhvrmgr {
   my $self = shift;
   return $self->{bhvrmgr};
}

sub digger {
   my $self = shift;
   return $self->{digger};
}

sub jobmgr {
   my $self = shift;
   return $self->{jobmgr};
}
sub datamgr {
   my $self = shift;
   return $self->{datamgr};
}

sub name {
   my $self = shift;
   return ref($self);
}



1;
