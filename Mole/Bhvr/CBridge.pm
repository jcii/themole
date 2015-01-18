################################################################################
##
## Mole::BHvr::CBridge.pm
##
##
## $Author: themole $
## $Revision: 1.4 $
## $Date: 2004/04/19 17:13:30 $
##
################################################################################
package Mole::Bhvr::CBridge;
use Mole::Bhvr;
use Mole::Message;
@ISA = qw(Mole::Bhvr);
use strict;
#use Mole::Job::Proto::Systable;
#use Mole::Job::Proto::Attable;
#use Mole::Job::Proto::Fdbtable;
my $debug = 1;
sub new {
   my $package = shift;
   my $self = {};
   $self->{bhvrmgr}  = shift;
   $self->{attable}  = 0;
   $self->{iftable}  = 0;
   $self->{fdbtable} = 0;
   $self->{vtptable} = 0;
   bless $self, $package;
   printf("%s::new \n", ref($self)) if $debug;
   return $self;
}
##
## TODO This will need to be more flexible. I will
## want to get job-defs without instantiating new job refs.
##

sub evaluate  {
   my $self = shift;
   my $bhvrmgr= $self->bhvrmgr;
   my $digger = $bhvrmgr->digger;
   my $datamgr= $digger->datamgr;
   my @datamgrs = $datamgr->list_mgrs;
   foreach my $mgrname (@datamgrs) {
      printf("%s::evaluate MGRNAME=%s\n", ref($self), $mgrname) if $debug;
      ##
      ## Do I need to send messages requesting data?
      ##
      $self->_eval($mgrname);
      ##
      ## Process changes from each data maanger
      ##
      $self->_process($mgrname);

   }
}

sub _process {
   my $self = shift;
   my $mgrname = shift;
   my $bhvrmgr= $self->bhvrmgr;
   my $digger = $bhvrmgr->digger;
   my $datamgr= $digger->datamgr;
   my $jobmgr = $digger->jobmgr;
   my $snmpmgr = $datamgr->get_mgr($mgrname);
   ##
   ## Determine if a complete set of data has returned and process
   ##
   my $vtp  = $snmpmgr->get_branch($Mole::Message::Vtptable::OID);
   my $fdb   = $snmpmgr->get_branch($Mole::Message::Fdbtable::OID);
   my $vtpcnt = scalar keys(%{$vtp});
   my $fdbcnt = scalar keys(%{$fdb});
   #my $arp  = $snmpmgr->get_branch($Mole::Message::Attable::OID);
   ##
   ##
   ##
   if ($vtpcnt && $fdbcnt) {
      printf("%s::_process MGR=%s %d VTP=%s FDB=%s\n", ref($self),
                                           $mgrname, time,
                                           $vtpcnt,
                                           $fdbcnt) if $debug;
   ##
   ##
   ##
      #my @tbl = $snmpmgr->fmttbl($Mole::Message::Iftable::OID, '.1.2', 22);
      #foreach my $row (@tbl) { printf("%s\n", join("\t", @$row)); }
      my @tbl = $snmpmgr->fmttbl($Mole::Message::Vtptable::OID, '.1.2', 18);
      foreach my $row (@tbl) { printf("%s\n", join("\t", @$row)); }
      my @tbl = $snmpmgr->fmttbl($Mole::Message::Fdbtable::OID, '.1.1', 3);
      foreach my $row (@tbl) { printf("%s\n", join("\t", @$row)); }
      exit(0);
   }
}


sub _eval {
   my $self = shift;
   my $mgrname = shift;
   my $bhvrmgr = $self->bhvrmgr;
   my $digger  = $bhvrmgr->digger;
   my $datamgr = $digger->datamgr;
   my $jobmgr  = $digger->jobmgr;
   my $msg;
   my $snmpmgr = $datamgr->get_mgr($mgrname);
   ##
   ## TODO Need function to get primary port/rostr
   ##

   ##
   ## TODO Need to know which jobs already exist so
   ## I can stage jobs based on the results of other jobs
   ## (Dont execute attable until iftable returns and IPs 
   ##  are registerd)

   ##
   ## Vlan Table
   ##
   unless ($self->{vtptable}) {
      $msg = Mole::Message::Vtptable->new;
      $msg->dstip('localhost');
      $msg->dstargs({port   => $snmpmgr->port,
                     rostr  => $snmpmgr->RO,
      });
      $jobmgr->add($msg);
      $self->{vtptable} = 1;
   }
   ##
   ## Fdb table
   ## 
   my @tbl = $snmpmgr->fmttbl($Mole::Message::Vtptable::OID, '.1.2', 18);
   unless ($self->{fdbtable} && $#tbl > -1) {
      foreach my $row (@tbl) {
         $row->[0] =~ /\.(\d+)$/;
         my $vlan = $1;
         $msg = Mole::Message::Fdbtable->new;
         $msg->dstip('localhost');
         $msg->dstargs({port   => $snmpmgr->port,
                        rostr  => $snmpmgr->RO,
                        rovar  => $vlan
         });
         $jobmgr->add($msg);
         $self->{fdbtable} = 1;
      }
   }
   ##
   ## CDP Table
   ##
 
   ##
   ## Attable
   ##
}

1;
