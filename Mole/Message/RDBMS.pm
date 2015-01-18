################################################################################
##
## Mole::Message::RDBMS.pm
##
## $Author: themole $
## $Revision: 1.1 $
## $Date: 2004/04/19 18:24:51 $
##
################################################################################
package Mole::Message::RDBMS;
use Mole::Message;
@ISA = qw(Mole::Message);
use strict;
use warnings;
sub new {
   my $package = shift;
   my $self = {};
   bless $self, $package;
   ##
   ## mgmtip, port, an rostr have to be set after creation
   ##
   $self->action($Mole::RDBMS::ALIAS);
   $self->dstargs({datamgr => 'Mole::Data::RDBMS',
                   name    => undef,
                  }
   );
   return $self;
}
                                                                                                                                               
1;

