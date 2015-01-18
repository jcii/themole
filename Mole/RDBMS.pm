#!/usr/local/bin/perl
package Mole::RDBMS;
################################################################################
##
##
##
##
##
################################################################################
use strict;
use warnings;

use POE;
use POE::Component::LaDBI;
use Mole::Message;
our $ALIAS = "RDBMS";
our $_ALIAS = "_rdbms_localhost";
our $DSN;
our $USER;
our $PASSWD;
my $debug = 0;
sub spawn {
   my $package = shift;
   my $self = $package->new(@_);

   POE::Component::LaDBI->create(Alias => $_ALIAS) 
   or die "Failed to create a POE::Component::LaDBI session\n";
   POE::Session->create ( object_states => [ 
                             $self => { _start        => '_start',
                                        _stop         => '_stop',
                                        connect       => 'connect',
                                        connected     => 'connected',
                                        execute       => 'process',
                                        selectall     => 'process',
                                        selectall_hash=> 'process',
                                        commit        => 'process',
                                        rollback      => 'process',
                                        do            => 'process',
                                        fetchrow      => 'process',
                                        fetchall      => 'process',
                                        fetchrow_hash => 'process',
                                        return        => 'handler',
                                        dberror       => 'dberror',
                                        shutdown      => 'shutdown'
                                      },
                          ],
   )
   or die "Failed to create a Mole::RDBMS session\n";
}

sub new {
   my $package = shift;
   ($DSN, $USER, $PASSWD) = @_;
   my $self    = {};
   $self->{dbh_id} = undef;
   bless $self, $package;
  
   return $self;
}
   
sub  _start {
   my ($kernel, $self) = @_[KERNEL, OBJECT];
   $kernel->alias_set($ALIAS);
   ##
   ## TODO start message
   ## TODO Real SuccessEvent
   ## TODO abstract start/restart behavior
   ##
   $kernel->call($ALIAS, 'connect');
}

sub connect {
   my ($kernel, $self) = @_[KERNEL, OBJECT];
   $kernel->post($_ALIAS => "connect",
              SuccessEvent => "connected",
              FailureEvent => "dberror",
              Args => [$DSN, $USER,$PASSWD, {AutoCommit=>1}],
              UserData => $self);
}

sub  _stop {
       print STDERR "_stop: client session ended.\n";
}

sub shutdown {
       print STDERR "shutdown: sending shutdown to $ALIAS\n";
       #$_[KERNEL]->post($ALIAS => "shutdown");
}
sub connected {
       my ($dbh_id, $datatype, $data, $self) = @_[ARG0..ARG3];
       printf("%s::connected RDBMS returned dbh handle\n", ref($self)) if $debug;
       $self->{dbh_id} = $dbh_id;

}
sub process {
   my ($kernel, $state, $msg, $self) = @_[KERNEL, STATE, ARG0, OBJECT];
   my $dbh_id = $self->{dbh_id};
   ##
   ## TODO need more rigorous check to see if dbh is open or closed
   ##
   unless (defined($dbh_id)) {
      $kernel->post($ALIAS, $state, $msg);
      $kernel->call($ALIAS, 'connect');
   }
   #print STDERR "selectall: dbh_id=$dbh_id\n";
   $msg->debug('Mole::RDBMS::'.$state) if $debug;
   my $Args;
   if ($state eq 'do') {
     $Args = [ $msg->dstargs('sql'), 
               defined($msg->dstargs('attr')) ? $msg->dstargs('attr') : undef, 
               @{ $msg->dstargs('bindval') }
             ] ;
   } else {
     $Args = [ $msg->dstargs('sql') ] ;

   }
   $kernel->post($_ALIAS => $state,
                 ##
                 ## TODO Success event should make message and post
                 ##
                 SuccessEvent => "return", #handler
                 FailureEvent => "dberror",
                 HandleId     => $dbh_id,
                 UserData     => $msg,
                 Args         => $Args
   );
}

sub handler{
   my ($dbh_id, $datatype, $data, $msg) = @_[ARG0..ARG3];
   #print STDERR "display_results: dbh_id=$dbh_id\n";
   if ($datatype eq 'TABLE') {
      my $rtnmsg = &_rtnmsg($msg);
      $rtnmsg->dstargs( {data => $data} );
      $rtnmsg->debug('Mole::RDBMS::handler') if $debug;
      $poe_kernel->post($rtnmsg->dstsess, $rtnmsg->dstevent, $rtnmsg);
   }
      
}

sub _rtnmsg {
   my $msg = shift;
   my $dstargs = $msg->dstargs;
   my $rtnmsg = Mole::Message::RDBMS->new;
   $rtnmsg->dstsess($msg->orgsess);
   $rtnmsg->dstevent($msg->orgevent);
   foreach my $key (keys(%{$dstargs})) {
      ##
      ## Any key in dstargs will not be copied into return.
      ##
      next if (substr($key, 0, 1) eq '_');
      $rtnmsg->dstargs( {$key => $msg->dstargs($key)} );
   }
   return $rtnmsg;
}

sub disconnect {
   my ($self, $session, $kernel) = @_[OBJECT, SESSION, KERNEL];

       $kernel->post($ALIAS => "disconnect",
                        SuccessEvent => "shutdown",
                        FailureEvent => "dberror",
                        HandleId     => $self->{dbh_id});
}

sub dberror {
   my ($dbh_id, $errtype, $errstr, $err) = @_[ARG0..ARG3];
   print "dberror: dbh_id  = $dbh_id\n";
   print "dberror: errtype = $errtype\n";
   print "dberror: errstr  = $errstr\n";
   print "dberror: err     = $err\n" if $errtype eq "ERROR";
   $_[KERNEL]->yield("shutdown");
   exit(0);
} 
sub oratmfmt {
   my $time = shift;
   my $FMT = 'YYYYMMDDHH24MISS';
   if ($time =~ /^\d+$/) {
      my @tm = localtime($time);
      return sprintf("to_date('%.4d%.2d%.2d%.2d%.2d%.2d','%s')", $tm[5]+1900,
                                                                 $tm[4]+1,
                                                                 $tm[3],
                                                                 $tm[2],
                                                                 $tm[1],
                                                                 $tm[0],
                                                                 $FMT);
   }
   if ($time =~ /^(\d{1,2})\/(\d{1,2})\/(\d{4,4})\s+(\d{1,2})\:(\d{1,2})\:(\d{1,2})\s*(\w*)/) {
      my $day = $1;
      my $mon = $2-1;
      my $year= $3;
      my $hr  = $4;
      my $min = $5;
      my $sec = $6;
      my $ampm= $7;
      if ($ampm =~ /PM/i && $hr != 12) { $hr += 12; }
      return timelocal($sec, $min, $hr, $day, $mon, $year);
   }
   if ($time =~ /^\w+$/) {
      return sprintf("to_char(%s, '%s')", $time, 'DD/MM/YYYY HH24:MI:SS');
   }
}

1;

