################################################################################
##
## Mole::Message::Attable.pm
##
## $Author: themole $
## $Revision: 1.1 $
## $Date: 2004/04/07 02:05:56 $
##
################################################################################
package Mole::Message::Attable;
use Mole::Message;
@ISA = qw(Mole::Message);
use strict;
use warnings;
#our $OID='.1.3.6.1.2.1.4.22.1.4';
our $OID='.1.3.6.1.2.1.4.22';
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
                   name     => 'Attable',
                   longevity=> 3600
                  }
   );
   return $self;
}
1;
