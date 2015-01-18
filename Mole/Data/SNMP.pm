################################################################################
##
## Mole::Data::SNMP.pm
##
##
## $Author: u169809 $
## $Revision: 1.5 $
## $Date: 2004/06/15 14:43:42 $
##
################################################################################
package Mole::Data::SNMP;
use Net::SNMP;
use Mole::Data;
use Data::Dumper;
@ISA = qw(Mole::Data);
use strict;
my $debug = 0;
##
## TODO Replace with data from iana.org
##
my @vendorID = ( ['.1.3.6.1.4.1.2',    'IBM'       ],
                 ['.1.3.6.1.4.1.9',    'Cisco'     ],
                 ['.1.3.6.1.4.1.11',   'HP'        ],
                 ['.1.3.6.1.4.1.23',   'Novell'    ],
                 ['.1.3.6.1.4.1.42',   'Sun'       ],
                 ['.1.3.6.1.4.1.45',   'Bay'       ],
                 ['.1.3.6.1.4.1.253',  'Xerox'     ],
                 ['.1.3.6.1.4.1.311',  'Microsoft' ],
                 ['.1.3.6.1.4.1.641',  'Lexmark'   ],
                 ['.1.3.6.1.4.1.930',  'Centillion'],
                 ['.1.3.6.1.4.1.1977',  'NetworkHarmoni'],
                 ['.1.3.6.1.4.1.2021', 'Linux'     ],
                 ['.1.3.6.1.4.1.5528', 'NetBotz'   ]
               );
sub new {
   my $package = shift;
   my $self = {};
   $self->{datamgr} = shift;
   $self->{ip}      = shift;
   $self->{port}    = shift;
   $self->{RO}      = shift;
   $self->{vendor}  = shift;
   $self->{name}    = undef;
   $self->{mib}     = {};
   $self->{mibage}  = {};
   return bless $self, $package;
}

sub ip {
   my ($self, $val) = @_;
   return $self->{ip} unless defined($val);
   $self->{ip} = $val;
}

sub port {
   my ($self, $val) = @_;
   return $self->{port} unless defined($val);
   $self->{port} = $val;
}


sub RO {
   my ($self, $val) = @_;
   return $self->{RO} unless defined($val);
   $self->{RO} = $val;
}

sub name {
   my ($self, $val) = @_;
   return $self->{name} unless defined($val);
   $self->{name} = $val;
}
################################################################################
sub process {
   my $self = shift;
   my $msg  = shift;
   $msg->debug(ref($self).'::process---') if $debug;
   if ($msg->dstargs('datamgr') eq 'Mole::Data::SNMP') {
      my $varlist = $msg->dstargs('data');
      my $oid     = $msg->dstargs('oid');
      ##
      ## Get branch from current $mib as identified by $oid
      ##
      my $cur_brnh = $self->get_branch($oid, $self->mib);
      my $diffs    = $self->diff_tree($cur_brnh, $varlist);
      $self->update_cache($diffs);
   }
   if ($msg->dstargs('datamgr') eq 'Mole::Data::RDBMS') {
      #print Dumper $self, $msg;
      my $data= $msg->dstargs('data');
      if ($#$data == -1) {
         $self->{'RDBMS::nodeid'} = -1;
      }  else {
         $self->{'RDBMS::nodeid'} = $data->[0]->[0];
      }
      printf("%s::process DATAMGR=%s NODEID=%s\n", ref($self), $msg->dstargs('datamgr'), $self->{'RDBMS::nodeid'});
   }

}

################################################################################
sub mib {
   my $self = shift;
   return $self->{mib};
}

################################################################################
sub get_branch {
   my $self = shift;
   my $base = shift;
   my $mib  = shift;
   unless (defined($mib)) { $mib = $self->mib; }
   my $branch = {};
   foreach my $oid (Net::SNMP::oid_lex_sort( keys(%{$mib}) )) {
      if (Net::SNMP::oid_base_match($base, $oid)) {
         $branch->{$oid} = $mib->{$oid};
      }
   }
   return $branch;
}

################################################################################
sub update_cache {
   my $self = shift;
   my $diffs = shift;
   my $mib = $self->{mib};
   my $mibage = $self->{mibage};
   my $chg;
   my $oid;
   my $vb;

   foreach my $diff (@$diffs) {
      $chg = $diff->[0];
      $oid = $diff->[1];
      $vb  = $diff->[2];
      ##
      ##
      ##
      if ($chg eq "INS" || $chg eq "UPD") {
         $mib->{$oid} = $vb;
         $mibage->{$oid} = time;
      } 
      ##
      ## TODO How do I record disappearance if I delete oid?
      ##
      if ($chg eq "DEL") {
         #printf("%s::update_cache MIB=%s MIBAGE=%s\n", ref($self), scalar keys(%{$mib}), scalar keys(%{$mib}));
         delete($mib->{$oid});
         delete($mibage->{$oid});
         #printf("%s::update_cache MIB=%s MIBAGE=%s\n", ref($self), scalar keys(%{$mib}), scalar keys(%{$mib}));
      }
      $self->debug($chg, $oid, $vb) if $debug;
   }
}

################################################################################
sub diff_tree {
   my $self = shift;
   my $curr = shift;
   my $new  = shift;
   my $diff = [];
   ##
   ## Find new (INS) rows
   ##
   foreach my $oid (Net::SNMP::oid_lex_sort( keys(%{$new}) )) {
      unless (exists($curr->{$oid})) {
         push(@$diff, ["INS", $oid, $new->{$oid}]);
      }
   }
   ##
   ## Find changed (UPD) rows
   ##
   foreach my $oid (Net::SNMP::oid_lex_sort( keys(%{$new}) )) {
      if (exists($curr->{$oid}) && $curr->{$oid} ne $new->{$oid}) {
         push(@$diff, ["UPD", $oid, $new->{$oid}]);
      }
   }
   ##
   ## Find deleted (DEL) rows
   ##
   foreach my $oid (Net::SNMP::oid_lex_sort( keys(%{$curr}) )) {
      unless (exists($new->{$oid})) {
         push(@$diff, ["DEL", $oid, $curr->{$oid}]);
      }
   }
   return $diff;
}

################################################################################
sub get_sysname {
   my $self = shift;
   my $mib  = $self->{mib};
   my $name= $mib->{'.1.3.6.1.2.1.1.5.0'};
   return '<unknown>' unless defined($name);
   return $name;
}

sub get_svcs {
   my $self = shift;
   my $mib  = $self->{mib};
   my $services   = $mib->{'.1.3.6.1.2.1.1.7.0'};
   return 0 unless defined($services);
   return $services;
}

sub get_vendor {
   my $self = shift;
   my $mib  = $self->{mib};
   my $objid = $mib->{'.1.3.6.1.2.1.1.2.0'};
   return 'unknown' unless defined($objid);
   foreach my $row (@vendorID) {
      if (Net::SNMP::oid_base_match($row->[0], $objid)) {
         return $row->[1];
      }
   }
   return 'unknown';
}

sub get_objectid {
   my $self = shift;
   my $mib  = $self->{mib};
   my $objid = $mib->{'.1.3.6.1.2.1.1.2.0'};
   return 'unknown' unless defined($objid);
   return $objid;
}

sub get_systable {
   my $self = shift;
   my $mib  = $self->{mib};
   return ($mib->{'.1.3.6.1.2.1.1.1.0'},
           $mib->{'.1.3.6.1.2.1.1.2.0'},
           $mib->{'.1.3.6.1.2.1.1.3.0'},
           $mib->{'.1.3.6.1.2.1.1.4.0'},
           $mib->{'.1.3.6.1.2.1.1.5.0'},
           $mib->{'.1.3.6.1.2.1.1.6.0'},
           $mib->{'.1.3.6.1.2.1.1.7.0'});
  

}
##
##
## Assumptions: The $table is a the oid of a Table from mib-defintions since
##
sub fmttbl {
   my $self = shift;
   my $table = shift;
   my $mnrbrnch = shift;
   my $mxntry = shift;
   my @grps;
   my $grp;
   my @tbl;
   my $suffix;
   my $mnrstrt;
      $mnrbrnch =~ /\.(\d+)$/;
      $mnrstrt = $1;
##
   ## Take everything from the minor branch down as a group id
   ## TODO This is costly. Need to enumerate through one copy
   ## of data
   ##
   my $ptrn = $table . $mnrbrnch;
   my $mib = $self->get_branch($ptrn);
      #my $ptrn = join('\.', split('\.', $foo));
     
   foreach my $oid (Net::SNMP::oid_lex_sort( keys( %{$mib} ) )) {
      ##
      ## TODO Kludge. assuming unverified structure behavior. Assumes 0
      ## will be consistently present or consistently absent.
      ##
      if ($oid =~ /$ptrn\.0$/) {
         $oid =~ /$ptrn([\d\.]+)\.0$/;
         $grp = $1;
         $suffix = '.0';
      } else { 
         $oid =~ /$ptrn([\d\.]+)$/;
         $grp = $1;
         $suffix = '';
      }
      push(@grps, $grp); 
   }
   ##
   ## 
   ##
      $mib = $self->get_branch($table);
      foreach $grp (@grps) {
         my $array = [];
         push (@$array, $grp);
         foreach my $entry ($mnrstrt..$mxntry) {
            my $key;
            $key = $table . '.1.' . $entry. $grp . $suffix;
            push(@$array, $mib->{$key});
         }
         push(@tbl, $array);
      }
   return @tbl;

}

################################################################################
sub debug { 
   my $self = shift;
   my $chg  = shift;
   my $oid  = shift;
   my $vb   = shift;
   return unless $debug;
   printf("%s::debug %d CHG=%s\t%s = %s\n",
          ref($self),
          time,
          $chg,
          $oid,
          $vb,
         );
}

1;
