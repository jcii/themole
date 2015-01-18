################################################################################
##
## Mole::Message::Iftable.pm
##
## $Author: themole $
## $Revision: 1.2 $
## $Date: 2004/04/19 17:13:30 $
##
################################################################################
package Mole::Message::Iftable;
use Mole::Message;
@ISA = qw(Mole::Message);
use strict;
use warnings;
our $OID=".1.3.6.1.2.1.2.2";
sub new {
   my $package = shift;
   my $self = {};
   bless $self, $package;
   ##
   ## mgmtip, port, an rostr have to be set after creation
   ##
   $self->dstip('localhost');
   $self->dstsess("SNMP");
   $self->dstevent("getbulk");
   #$self->action('post');
   $self->dstargs({oid      => $OID,
                   datamgr  => 'Mole::Data::SNMP',
                   name     => 'Iftable',
                   longevity=> 21600
                  }
   );
   return $self;
}
                                                                                                                                               
1;

