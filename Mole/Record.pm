################################################################################
##
## Mole::Record.pm
##
## $Author: themole $
## $Revision: 1.1 $
## $Date: 2004/04/07 02:05:15 $
##
## TODO this might become an abstraction between Mole Registry entries and diggers
##
################################################################################
package Mole::Record;
use strict;

sub new {
   my $pkg = shift;
   my $self = {};
   bless $self, $pkg;
   $self->{digger} = undef;
   return $self;
}

sub check {}

sub digger {
   my $self = shift;
   my $digger = shift;
   ##
   ##
   ##
   if (defined($digger) && defined($self->{digger})) {
      return -1; 
   }
   ##
   ##
   ##
   if (defined($digger) && not defined($self->{digger})) {
      $self->{digger} = $digger;
   }
   return $self->{digger};
}

sub keys  {}

1;
