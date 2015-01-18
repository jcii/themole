################################################################################
package Mole::Bhvr::SSM;
use POE;
use Mole::Bhvr;
use Mole::Message;
use Data::Dumper;
@ISA = qw(Mole::Bhvr);
my $debug = 1;
#use Mole::Job::Proto::Systable;
#use Mole::Job::Proto::Attable;

sub new {
   my $package = shift;
   my $self = {};
   $self->{bhvrmgr} = shift;
   $self->{NH::Agent} = 0;
   $self->{iftable} = 0;
   $self->{RDBMS::time} = undef;
   $self->{RDBMS::nodeid} = undef;
   $self->{NH::srLogMon} = 0;
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
      printf("%s::evaluate MGRNAME=%s\n", ref($self), $mgrname) if $debug;
      ##
      ## Do I need to send messages requesting data?
      ##
      $self->_request($mgrname);
      ##
      ## Process changes from each data maanger
      ##
      #$self->_process($mgrname);
      
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
   my $if   = $snmpmgr->get_branch($Mole::Message::Iftable::OID);
   my $ip  = $snmpmgr->get_branch($Mole::Message::Ipaddrtable::OID);
   my $agent = $snmpmgr->get_branch($Mole::Message::NH::Agent::OID);
   ##
   ##
   ##
   my $digname = $digger->alias;
   $poe_kernel->signal($digname, 'QUIT');
   if (scalar keys(%{$ip})) {
      $self->{ipaddrtable} = time;
   }
   ##
   ##
   ##
   if (scalar keys(%{$if}) && scalar keys(%{$ip}) && scalar keys(%{$agent})) {
      my @tbl = $snmpmgr->fmttbl($Mole::Message::Ipaddrtable::OID, '.1.1', 5);
      print "----------------------\n";
      foreach my $row (@tbl) { printf("%s\n", join("\t", @$row)); }
      my @tbl = $snmpmgr->fmttbl($Mole::Message::Iftable::OID, '.1.1', 22);
      print "----------------------\n";
      foreach my $row (@tbl) { printf("%s\n", join("\t", @$row)); }
      ##
      my @tbl = $snmpmgr->fmttbl($Mole::Message::NH::Agent::OID . '.5', '.1.2', 8);
      print "----------------------\n";
      foreach my $row (@tbl) { printf("%s\n", join("\t", @$row)); }
      ##
      my @tbl = $snmpmgr->fmttbl($Mole::Message::NH::Agent::OID . '.8', '.1.2', 7);
      print "----------------------\n";
      foreach my $row (@tbl) { printf("%s\n", join("\t", @$row)); }
      ##
      my @tbl = $snmpmgr->fmttbl($Mole::Message::NH::Agent::OID . '.9', '.1.2', 8);
      print "----------------------\n";
      foreach my $row (@tbl) { printf("%s\n", join("\t", @$row)); }
      #exit(0);
   }
}

##
## _eval determines if Messages need to be sent
##
sub _request {
   my $self = shift;
   my $mgrname = shift;
   my $bhvrmgr= $self->bhvrmgr;
   my $digger = $bhvrmgr->digger;
   my $datamgr= $digger->datamgr;
   my $jobmgr = $digger->jobmgr;
   my $msg;
   my $snmpmgr = $datamgr->get_mgr($mgrname);
   ##
   ## 
   ## 
   if ($snmpmgr->{RDBMS::nodeid} < 1 || $snmpmgr->{RDBMS::time} < time - 300) {
      printf("%s::_request SELECTALL=%s, %s\n", ref($self), $snmpmgr->ip, $snmpmgr->get_sysname) if $debug;
      my $msg = Mole::Message::RDBMS->new;
      $msg->dstevent('selectall');
      $msg->dstargs({sql => 'select * from NODES ' .
                            'where mgmtip = \''. $snmpmgr->ip . '\' '. 
                            'AND sysname = \'' . $snmpmgr->get_sysname . '\'',
                     mgrname=> $mgrname,
                     name   => 'get_by_mgmtip_sysname'
                    });
      $jobmgr->add($msg);
      $snmpmgr->{RDBMS::time} = time;
   }
   ##
   ## Device doesn't exist in node database, create
   ## -1 means nothing returned from RDBMS lookup
   ## 0 means I have sent an creation message
   ##
   if ($snmpmgr->{RDBMS::nodeid} == -1) {
      printf("%s::_request INSERT=%s, %s\n", ref($self), $snmpmgr->ip, $snmpmgr->get_sysname) if $debug;
      my $msg = Mole::Message::RDBMS->new;
      $msg->dstevent('do');
      $msg->dstargs({sql => q(insert INTO NODES (nodeid, sysname, sysdescr, sysobjectid, sysservices, syslocation,syscontact,category,mgmtip,snmp_lasttime) VALUES (SEQ_NODES_NID.nextval, ?, ?, ?, ?, ?, ?, ?, ?, to_date(?, 'YYYYMMDDHH24MISS'))),
                     mgrname=> $mgrname,
                     name   => 'insert_node'
                    });
      my @systable = $snmpmgr->get_systable;
      my @tm = localtime(time);

      $msg->dstargs({bindval => [ #'SEQ_NODES_NID.nextval', 
                                 #'2',
                                 $systable[4],  # sysname
                                 $systable[0],  # sysdescr
                                 $systable[1],  # iysobjid
                                 $systable[6],  # services
                                 $systable[5],  # location
                                 $systable[3],  # contact
                                 "SSM",
                                 $snmpmgr->ip, 
                                 sprintf("%.4d%.2d%.2d%.2d%.2d%.2d", $tm[5]+1900,
                                                                 $tm[4]+1,
                                                                 $tm[3],
                                                                 $tm[2],
                                                                 $tm[1],
                                                                 $tm[0])
                                 ] 
                    } 
                   );
      $jobmgr->add($msg);
      $snmpmgr->{RDBMS::nodeid} = 0;
   }
   ##
   ## Ipaddrtable & IfTable
   ##
   unless ($self->{ipaddrtable}) {
      $self->_Ipaddrtable_msg($snmpmgr);
   }
   ##
   if (!$self->{iftable} && $self->{ipaddrtable} > time - 21600) {
      $self->_Iftable_msg($snmpmgr);
   }
   ##
   if (!$self->{NH::Agent} && $self->{ipaddrtable} > time - 21600) {
      $self->_NHAgent_msg($snmpmgr);
   }
}

sub _Ipaddrtable_msg {
   my $self = shift;
   my $snmpmgr = shift;
   my $bhvrmgr= $self->bhvrmgr;
   my $digger = $bhvrmgr->digger;
   my $jobmgr = $digger->jobmgr;
   my $msg;
      $msg = Mole::Message::Ipaddrtable->new;
      $msg->action($Mole::Client::ALIAS);
      $msg->dstip('localhost');
      $msg->dstargs({port   => $snmpmgr->port,
                     rostr  => $snmpmgr->RO,
                    });
      $jobmgr->add($msg);
      $self->{ipaddrtable} = time;
}

sub _Iftable_msg {
   my $self = shift;
   my $snmpmgr = shift;
   my $bhvrmgr= $self->bhvrmgr;
   my $digger = $bhvrmgr->digger;
   my $jobmgr = $digger->jobmgr;
   my $msg;
   $msg = Mole::Message::Iftable->new;
   $msg->dstip('localhost');
   $msg->action($Mole::Client::ALIAS);
   $msg->dstargs({port   => $snmpmgr->port,
                  rostr  => $snmpmgr->RO,
                 });
   $jobmgr->add($msg);
   $self->{iftable} = time;
}

sub _NHAgent_msg {
   my $self = shift;
   my $snmpmgr = shift;
   my $bhvrmgr= $self->bhvrmgr;
   my $digger = $bhvrmgr->digger;
   my $jobmgr = $digger->jobmgr;
   my $msg;
   $msg = Mole::Message::NH::Agent->new;
   $msg->dstip('localhost');
   $msg->action($Mole::Client::ALIAS);
   $msg->dstargs({port   => $snmpmgr->port,
                  rostr  => $snmpmgr->RO,
                 });
   $jobmgr->add($msg);
   $self->{NH::Agent} = time;
}

1;
