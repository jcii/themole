################################################################################
##
## Mole::Bhvr::Unknown.pm
##
##
## $Author: themole $
## $Revision: 1.7 $
## $Date: 2004/04/19 17:13:30 $
##
################################################################################
package Mole::Bhvr::Unknown;
use Mole::Bhvr;
@ISA = qw(Mole::Bhvr);
use strict;
use warnings;
use Mole::Message::Systable;
our $STALEDISCO = 3600;

sub new {
   my $package = shift;
   my $self = {};
   $self->{bhvrmgr} = shift;
   return bless $self, $package;
}
##
## TODO This will need to be more flexible. I will
## want to get job-defs without instantiating new job refs.
##
sub jobs {
   my $self = shift;
   my $bhvrmgr= $self->bhvrmgr;
   my $digger = $bhvrmgr->digger;
   my $datamgr= $digger->datamgr;
   my $msg;
   my @msgs;
   foreach my $array (@{$datamgr->snmp_get_roports}) {
      $msg = Mole::Message::Systable->new;
      $msg->dstip('localhost');
      $msg->dstargs({port => $array->[1],
                     rostr=> $array->[0],
                    });
      push(@msgs, $msg);
   }
   ##
   ## 
   ##
   return (@msgs);
}
################################################################################
sub evaluate {
   my $self = shift;
   my $bhvrmgr= $self->bhvrmgr;
   my $digger = $bhvrmgr->digger;
   my $datamgr= $digger->datamgr;
   my $jobmgr = $digger->jobmgr;
   my $msg;
   my @msgs;
   ##
   ## If state unknown and time is 0 or old, start discovery
   ##
   my $discotm = $bhvrmgr->discovery;
   if ($bhvrmgr->state eq 'unknown' && $discotm < time - $STALEDISCO) {
      foreach my $array (@{$datamgr->snmp_get_roports}) {
         $msg = Mole::Message::Systable->new;
         $msg->dstip('localhost');
         $msg->dstargs({port => $array->[1],
                        rostr=> $array->[0],
                       });
         $msg->action($Mole::Client::ALIAS);
         $jobmgr->add($msg);
      }
   }

   ##
   ## TODO Do I know what I am?
   ## TODO Do I have SNMP? NetBIOS?
   ## TODO Whats changed?
   ##
   my @datamgrs = $datamgr->list_mgrs;
   foreach my $mgrname (@datamgrs) {
      printf("%s::evaluate DATAMGR=%s\n", ref($self), $mgrname);
      my $mgr = $datamgr->get_mgr($mgrname);
      ##
      ## If Data mgr is SNMP
      ##
      if (ref($mgr) eq 'Mole::Data::SNMP') {
         $mgr->debug;
         my $svc   = $mgr->get_svcs;
         my $vendor= $mgr->get_vendor;
         my $objid = $mgr->get_objectid;
         printf("%s::evaluate SNMPMGR=%s SVC=%s VENDOR=%s OBJID=%s\n", ref($self), 
                                                                       $mgrname, 
                                                                       $svc, 
                                                                       $vendor, 
                                                                       $objid);
         ##
         ## Add cisco routers & switches
         ##
         if ($svc & 6 && $vendor eq 'Cisco') { $bhvrmgr->add('router');} 
         if ($svc & 2 && $vendor eq 'Cisco') { $bhvrmgr->add('bridge');}
         ##
         ## TODO Abstract objid as identification
         ##
         if ($objid eq '.1.3.6.1.4.1.1977.1.6.1279.3') { $bhvrmgr->add('SSM');}
      }
   }
}

1;
