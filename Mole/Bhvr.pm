################################################################################
##
## Mole::Bhvr.pm
##
## $Author: themole $
## $Revision: 1.4 $
## $Date: 2004/04/07 02:05:15 $
##
################################################################################
package Mole::Bhvr;
use Mole::MDC;
@ISA = qw(Mole::MDC);
use strict;

#sub name {
#   my $self = shift;
#   return ref($self);
#}

sub evaluate {
   my $self = shift;
   my $bhvrmgr= $self->bhvrmgr;
   my $digger = $bhvrmgr->digger;
   my $datamgr= $digger->datamgr;
   ##
   ## TODO Do I know what I am?
   ## TODO Do I have SNMP? NetBIOS? 
   ## TODO Whats changed?
   ##
   my @datamgrs = $datamgr->list_mgrs;
   foreach my $mgr (@datamgrs) {
      printf("%s::evaluate DATAMGR=%s\n", ref($self), $mgr);
      #$mgr->identify;
   }
}

1;
##
## Behaviors define the following data mining jobs
##
## Name		Job Type	Job Session	Args	DataMgr
## sysTable	SNMP		OBJREF		ARYREF	OBJREF
## atTable	SNMP		OBJREF		ARYREF	OBJREF
## ifTable	SNMP		OBJREF		ARYREF	OBJREF
## fdbTable	SNMP		OBJREF		ARYREF	OBJREF
## vlans	SNMP		OBJREF		ARYREF	OBJREF
## HSRP		SNMP		OBJREF		ARYREF	OBJREF
## nbstat	NetBIOS		OBJREF		ARYREF	OBJREF
##
