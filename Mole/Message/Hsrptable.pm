################################################################################
##
## Mole::Message::Hsrptable.pm
##
## $Author: themole $
## $Revision: 1.1 $
## $Date: 2004/04/07 02:05:56 $
##
################################################################################
package Mole::Message::Hsrptable;
use Mole::Message;
@ISA = qw(Mole::Message);
our $OID=".1.3.6.1.4.1.9.9.106.1.2.1";
use strict;
use warnings;
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
   $self->action('post');
   $self->dstargs({oid      => $OID,
                   datamgr  => 'Mole::Data::SNMP',
                   name     => 'Hsrptable',
                   longevity=> 86400			# Once a day
                  }
   );
   return $self;
}
1;
