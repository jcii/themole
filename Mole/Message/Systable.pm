################################################################################
##
## Mole::Message::Systable.pm
##
## $Author: themole $
## $Revision: 1.2 $
## $Date: 2004/04/19 17:13:30 $
##
################################################################################
package Mole::Message::Systable;
use Mole::Message;
@ISA = qw(Mole::Message);
use strict;
use warnings;

sub new {
   my $package = shift;
   my $self = Mole::Message->new;
   bless $self, $package;
   ##
   ## mgmtip, port, an rostr have to be set after creation
   ##
   $self->dstip('localhost');
   $self->dstsess("SNMP");
   $self->dstevent("getbulk");
   $self->action($Mole::Snmp::ALIAS);
   $self->dstargs({oid      => ".1.3.6.1.2.1.1",
                   datamgr  => 'Mole::Data::SNMP',
                   name     => 'Systable',
                   longevity=> 21600
                  }
   );
   return $self;
}
                                                                                                                                               
1;

