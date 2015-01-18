################################################################################
##
## Mole::Message::NH::srLogMon.pm
##
## $Author: themole $
## $Revision: 1.1 $
## $Date: 2004/04/19 18:31:59 $
##
################################################################################
package Mole::Message::NH::srLogMon;
use Mole::Message;
@ISA = qw(Mole::Message);
use strict;
use warnings;
our $OID=".1.3.6.1.4.1.1977.9.4";
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
                   name     => 'NH::srLogMon',
                   longevity=> 3600
                  }
   );
   return $self;
}
                                                                                                                                               
1;

