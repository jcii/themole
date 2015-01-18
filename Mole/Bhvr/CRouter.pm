################################################################################
package Mole::Bhvr::CRouter;
use POE;
use Mole::Bhvr;
use Mole::Message;
@ISA = qw(Mole::Bhvr);
my $debug = 1;
#use Mole::Job::Proto::Systable;
#use Mole::Job::Proto::Attable;

sub new {
   my $package = shift;
   my $self = {};
   $self->{bhvrmgr} = shift;
   $self->{attable} = 0;
   $self->{iftable} = 0;
   $self->{hsrptable} = 0;
   return bless $self, $package;
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
      printf("%s::evaluate MGRNAME=%s\n", ref($self), $mgrname);
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
   my $hsrp = $snmpmgr->get_branch($Mole::Message::Hsrptable::OID);
   my $if   = $snmpmgr->get_branch($Mole::Message::Iftable::OID);
   my $arp  = $snmpmgr->get_branch($Mole::Message::Attable::OID);
   my $ip  = $snmpmgr->get_branch($Mole::Message::Ipaddrtable::OID);
   ##
   ##
   ##
   if (scalar keys(%{$ip})) {
      my @tbl = $snmpmgr->fmttbl($Mole::Message::Ipaddrtable::OID, '.1.1', 5);
      $self->{ipaddrtable} = time;
      foreach my $row (@tbl) { printf("%s\n", join("\t", @$row)); }
      my $digname = $digger->alias;
      $poe_kernel->signal($digname, 'QUIT');
   }
   if (scalar keys(%{$hsrp}) && scalar keys(%{$if}) && scalar keys(%{$arp})) {
      printf("%s::_process MGR=%s %d HSRP=%s IF=%s ARP=%s\n", ref($self),
                                                           $mgrname, time,
                                                           scalar keys(%{$hsrp}),
                                                           scalar keys(%{$if}),
                                                           scalar keys(%{$arp})) if $debug;
   ##
   ##
   ##
      my @tbl = $snmpmgr->fmttbl($Mole::Message::Iftable::OID, '.1.2', 22);
      foreach my $row (@tbl) { printf("%s\n", join("\t", @$row)); }
      my @tbl = $snmpmgr->fmttbl($Mole::Message::Hsrptable::OID, '.1.2', 17);
      foreach my $row (@tbl) { printf("%s\n", join("\t", @$row)); }
      my @tbl = $snmpmgr->fmttbl($Mole::Message::Attable::OID, '.1.1', 4);
      foreach my $row (@tbl) { printf("%s\n", join("\t", @$row)); }
      exit(0);
   }
}

##
## _eval determines if Messages need to be sent
##
sub _eval {
   my $self = shift;
   my $mgrname = shift;
   my $bhvrmgr= $self->bhvrmgr;
   my $digger = $bhvrmgr->digger;
   my $datamgr= $digger->datamgr;
   my $jobmgr = $digger->jobmgr;
   my $msg;
   my $snmpmgr = $datamgr->get_mgr($mgrname);
   ##
   ## Attable
   ##
   if (!$self->{attable} && $self->{ipaddrtable} > time - 21600) {
      $msg = Mole::Message::Attable->new;
      $msg->dstip('localhost');
      $msg->action('post');
      $msg->dstargs({port   => $snmpmgr->port,
                     rostr  => $snmpmgr->RO,
                    });
      $jobmgr->add($msg);
      $self->{attable} = 1;
      undef $msg;
   }
   ##
   ## CDP Table
   ## Ipaddrtable 
   ##
   ##
   unless ($self->{ipaddrtable}) {
      $msg = Mole::Message::Ipaddrtable->new;
      $msg->action('post');
      $msg->dstip('localhost');
      $msg->dstargs({port   => $snmpmgr->port,
                     rostr  => $snmpmgr->RO,
                    });
      $jobmgr->add($msg);
      undef $msg;
   }
 
   ##
   ## HRSP Table
   ##
   if (!$self->{hsrptable} && $self->{ipaddrtable} > time - 21600) {
      $msg = Mole::Message::Hsrptable->new;
      $msg->dstip('localhost');
      $msg->action('post');
      $msg->dstargs({port   => $snmpmgr->port,
                     rostr  => $snmpmgr->RO,
                    });
      $jobmgr->add($msg);
      $self->{hsrptable} = time;
      undef $msg;
   }
 
   ##
   ## Iftable not requested, request
   ##
   if (!$self->{iftable} && $self->{ipaddrtable} > time - 21600) {
      $msg = Mole::Message::Iftable->new;
      $msg->dstip('localhost');
      $msg->action('post');
      $msg->dstargs({port   => $snmpmgr->port,
                     rostr  => $snmpmgr->RO,
                    });
      $jobmgr->add($msg);
      $self->{iftable} = time;
      undef $msg;
   }
}


1;
