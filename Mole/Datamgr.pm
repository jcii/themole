################################################################################
##
## Mole::Datamgr.pm
##
##
## $Author: u169809 $
## $Revision: 1.7 $
## $Date: 2004/06/15 14:35:28 $
##
################################################################################
package Mole::Datamgr;
use Mole::MDC;
@ISA = qw( Mole::MDC );
use strict;
use Mole::Data::SNMP;
my $debug = 0;
##
##
##
sub new { 
   my $package = shift;
   my $self = {};
   $self->{digger}  = shift;
   $self->{roports} = shift;
   $self->{data}    = {};
   $self->{validroports} = [];
   return bless $self, $package;
}

##
## $args is packaged by the the Job class. Unpackaging will be
## job-dependent
##
sub handle {
   my $self = shift;
   my $msg = shift;
   
   printf("%s::handle RECEIVED %s\n", ref($self), $msg->dstargs('datamgr')) if $debug;
   ##
   ## Received SNMP response from moled
   ##
   if ($msg->dstargs('datamgr') eq 'Mole::Data::SNMP') {
      $self->_handle_snmp($msg);
      return;
   }
   ##
   ## Received RDBMS response from LaDBI
   ##
   if ($msg->dstargs('datamgr') eq 'Mole::Data::RDBMS') {
      $self->_handle_rdbms($msg);
      return;
   }
   printf("%s::handle NO DATAMGR CLASS for %s\n", ref($self), $msg->dstargs('datamgr')) if $debug;
}

sub evaluate {
   my $self = shift;
   ##
   ## TODO Am I new? Check cache. -> Do I need to load data?
   ## TODO Am I stale? Check RDBMS? Load/Save RDBMS data.
   ## 
   ## TODO Am I consistent? Have I mutated?
   ##

}


sub get_mgr {
   my $self = shift;
   my $mgrname = shift;
   my $data    = $self->{data};
   if (defined($data->{$mgrname})) {
      return $data->{$mgrname};
   } else {
      return undef;
   }
}

sub add_mgr {
   my $self = shift;
   my $mgrname = shift;
   my $mgr = shift;
   if ($self->get_mgr($mgrname)) {
      ## TODO error out if exists already
      return $self->get_mgr($mgrname);
   } else {
      my $data = $self->{data};
      $data->{$mgrname} = $mgr;
      return $mgr;
   }
}

sub list_mgrs {
   my $self = shift;
   my $data = $self->{data};
   return keys %{$data};
}
################################################################################
##
## SNMP-specific datamgr routines
##
################################################################################
##
## TODO Need to poll fresh list from MOLE Class
##
sub snmp_get_roports {
   my $self = shift;
   return $self->{roports};
}

sub snmp_del_roports {
   my $self = shift;
   my $rostr = shift;
   my $port = shift;
   my $roports = $self->{roports};
   my $ref;
   for (my $i = 0; $i < $#$roports; $i++) {
      $ref = $$roports[$i];
      if ($ref->[0] eq $rostr && $ref->[1] eq $port) {
         splice(@$roports, $i, 1);
      }
   }
}


sub snmp_valid_roports {
   my $self = shift;
   my $rostr = shift;
   my $port = shift;
   my $roports = $self->{validroports};
   my $ref;
   return $roports unless(defined($rostr) && defined($port));
   for (my $i = 0; $i <= $#$roports; $i++) {
      $ref = $$roports[$i];
      return if ($ref->[0] eq $rostr && $ref->[1] eq $port);
   }
   printf("%s::snmp_valid_roports ADDING RO=%s PORT=%s\n", ref($self), $rostr, $port);
   push(@$roports, [$rostr, $port]);
}

sub _handle_snmp {
   my $self = shift;
   my $msg = shift;
   my $varlist = $msg->dstargs('data');
   my $ip      = $msg->dstargs('mgmtip');
   my $port    = $msg->dstargs('port');
   my $RO      = $msg->dstargs('rostr');
   my $mgr;
   $msg->debug(ref($self).'::_handle_snmp') if $debug;
   ##
   ## If varlist is a HASH, its full of data.
   ## Else its an error message. Remove RO/port combo
   ## if data doesn't work.
   ## TODO make RO/port removal more robust
   ##
   if (ref($varlist) eq 'HASH') {
      ##
      ## Does SNMP data class exist for this ip/port/RO combo?
      ## Retrieve reference of create data manager
      ##
      my $mgrname = "SNMP-".$ip."-".$port."-".$RO;
      if ( defined($self->get_mgr($mgrname)) ) {
         $mgr = $self->get_mgr($mgrname);
      } else {
         $mgr = Mole::Data::SNMP->new($self, $ip, $port, $RO);
         $mgr->name($mgrname);
         $self->add_mgr($mgrname, $mgr);
      }
      ##
      ##
      ##
      $self->snmp_valid_roports($RO, $port);
      $mgr->process($msg);
   } else {
      $self->snmp_del_roports($RO, $port);
   }

   ##
   ## TODO Update some time or something that the data is current
   ##

}
################################################################################
##
## RDBMS-specific datamgr routines
##
################################################################################
sub _handle_rdbms {
   my $self = shift;
   my $msg = shift;
   my $mgrname = $msg->dstargs('mgrname');
   my $mgr = $self->get_mgr($mgrname);
   $msg->debug(ref($self) . '_handle_rdbms') if $debug;
   $mgr->process($msg);
}
1;
