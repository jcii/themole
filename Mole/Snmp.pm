package Mole::Snmp;
use strict;
use warnings;
use Carp;
use POE;
use Net::SNMP;
use Mole::Message;
my $debug = 0;
sub spawn {
   my $package = shift;
   my $self = $package->new();
   return POE::Session->create(
      object_states => [
         $self => { _start  => '_start',
                    get     => 'get',
                    getbulk => 'get',		# get() knows to use bulk and set maxrep value
                    execute => 'execute',
                    _child  => '_child',
                    _stop   => '_stop',
                  },
      ]
   );
}

sub new {
   my $package = shift; 
   return bless { queue    => {},
                  order    => [],
                  prttime  => 0,
                  timeout=> 5,			# timeout for Transport Layer
                  retry=> 1,
                  maxrepetitions => 25,		# number of rows for getbulk requests
                  maxsess  => 500,              # max number of sessiosn to create
                }, $package;
}

sub _start {
   my ($kernel, $self, $session) = @_[KERNEL, OBJECT, SESSION];
   $kernel->alias_set("SNMP");
   printf("%s Starting %s ID=%s\n", $$, ref($self),$session->ID);
}

sub _child {
}

sub _stop {
   my ($kernel, $self, $session) = @_[KERNEL, OBJECT, SESSION];
   printf("%s Stopping %s ID=%s\n", $$, ref($self),$session->ID);
}

sub execute {
   my ($kernel, $self) = @_[KERNEL, OBJECT];
   $self->_dequeue;
   my $queue = $self->{queue};
   ##
   ## Dispatch all N::S sessions. Handlers will determine if session 
   ## is to be closed or re-queued for additional processing (getbulks).
   ##
   printf("%s::execute %s SNMPQ %s\n", ref($self), time, scalar keys %{$queue}) if (time - $self->{prttime} > 5);
   $self->{prttime} = time;
   &snmp_dispatcher();
   printf("%s::execute Dispatcher returned\n", ref($self)) if $debug;
   ##
   ## Check if queue is empty. If its not then there are msgs to process
   ##
   if (scalar keys %{$queue}) { $poe_kernel->delay_set("execute", 2); }
} 
##
##
##
sub _handler {
   my $SNMPsession = shift; 
   my $self = shift;        
   my $sender  = shift;
   my $msg = shift;
   my $handler = shift;
   my $queue = $self->{queue};
   my $args = $msg->dstargs;
   my $varlist = $SNMPsession->var_bind_list();
   my $prefix = ref($self)."::_handler";
   my $RO = defined($args->{rovar}) ?  $args->{rostr} . '@' . $args->{rovar} : $args->{rostr};

   printf("%s %s %s %s\t%s\t%s\t%s\n", $prefix, 
                                       $SNMPsession, 
                                       $self, 
                                       $sender, 
                                       $handler,
                                       $args->{oid},  	# Formally called '$branch'
                                       $args->{state}) if $debug;
   $msg->debug($prefix) if $debug;
   ##
   ## If varlist isn't defined, the request timed out (or had some other problem)
   ##
   unless (defined $varlist) {
      printf("%s varlist undefined\n", $prefix) if $debug;
      ##
      ## TODO Construct Mole::Message here
      ##
      my $rtnmsg = $self->_rtnmsg($msg);
      $rtnmsg->dstargs({data => $SNMPsession->error});
      $rtnmsg->debug($prefix) if $debug;
      $poe_kernel->post($sender, $handler, $rtnmsg);
      $SNMPsession->close();
      return;
   }
   ##
   ## Cycle through varlist to move vars to hash to be posted to handler
   ##
   my $next;
   $msg->dstargs({data => {} }) unless defined ($msg->dstargs('data'));
   foreach my $oid (Net::SNMP::oid_lex_sort(keys(%{$varlist}))) {
      ##
      ## Check if a getbulk is being performed and end of table is reached
      ##
      if ($args->{state} eq "getbulk" && !Net::SNMP::oid_base_match($args->{oid}, $oid)) {
         printf("%s basematch failed\n", $prefix) if $debug;
         $next = undef;
         last;
      }
      ##
      ## Check if no object instances available which lexicographically
      ## follow the object in the request
      ##
      if ($varlist->{$oid} eq "endOfMibView") {
         printf("%s endOfMibView %s\n", $prefix, $varlist->{$oid}) if $debug;
         $next = undef;
         last;
      }
      $next = $oid; 
      ##
      ## Store oid+vars while I get more data from snmp stalk
      ##
      $args->{data}->{$oid} = $varlist->{$oid};   
      printf("%s oid: %s\t%s\t%s\n", $prefix, 
                                     $args->{oid}, 	# branch
                                     $oid, 
                                     $args->{data}->{$oid}) 
                                     if $debug;
   }
   ## 
   ## If $next defined then end of the table not reached
   ## 
   if ($args->{state} eq "getbulk" && defined($next)) {
      # TODO: create sub{} and de-duplicate with bulk request in get method
      my $mxrep = defined($args->{maxrep}) ? $args->{maxrep} : $self->{maxrepetitions};
      my $result = $SNMPsession->get_bulk_request(
         -callback       => [\&_handler, $self, $sender, $msg, $handler],
         -maxrepetitions => $mxrep,
         -varbindlist    => [$next]
      );
      ##
      ## An error here means a device stopped providing data mid-poll
      ##
      if (!defined($result)) {
         my $rtnmsg = $self->_rtnmsg($msg);
         $rtnmsg->dstargs({data => $SNMPsession->error});
         $rtnmsg->debug if $debug;
         $poe_kernel->post($sender, $handler, $rtnmsg);
         return;
      }

   } else {
      ##
      ## End of table reached, return oid data to caller if all outstanding sessions finished
      ##
      my $rtnmsg = $self->_rtnmsg($msg);
      $rtnmsg->dstargs({data => $args->{data}});
      $rtnmsg->debug($prefix) if $debug;
      $poe_kernel->post($sender, $handler, $rtnmsg);
      ##
      ## Remove N::S SNMPsession from stack and close Transport Layer socket associated
      ## with it.
      ##
      $SNMPsession->close();
      printf("%s queue count %s\n", $prefix, scalar keys %{$queue}) if $debug;
   }
}

sub _rtnmsg {
   my $self = shift;
   my $msg  = shift;
   my $rtnmsg = Mole::Message->new;
   $rtnmsg->orgip('localhost'); # TODO Assign from $mole->address or something.
   $rtnmsg->dstip($msg->orgip); # TODO Assign from $mole->address or something.
   $rtnmsg->dstsess($msg->orgsess);
   $rtnmsg->dstevent($msg->orgevent);
   $rtnmsg->action($Mole::Server::ALIAS);                # TODO make this useful
   my $dstargs = $msg->dstargs;
   foreach my $key (keys(%{$dstargs})) {
      ##
      ## Any key in dstargs will not be copied into return.
      ##
      next if (substr($key, 0, 1) eq '_');
      $rtnmsg->dstargs( {$key => $msg->dstargs($key)} );
   }
   return $rtnmsg;
}
##
## method to setup a Net::SNMP session w/ for a specific IP, ROCommunity & port (eventuallyt
## N::S sessions will execute with the POE session 'execute' reaches the top of the stack.
## If this method is called and no N::S sessions exist, enqueue a POE 'execute' session.
## 
sub get {
my ($self, $session, $sender, $state, $msg, $handler) = @_[OBJECT, SESSION, SENDER, STATE, ARG0, ARG1];
   my $prefix = ref($self)."::".$state;
   ##
   ## TODO Need to die gracefully if all arguments not supplied
   ##
   my $queue = $self->{queue};
   my $order = $self->{order};
   my $args = $msg->dstargs;
   $args->{state} = $state;
   $args->{_msghndlr} = $handler;
   $args->{_msgsndr} = $sender;
   my $mgmtip = $args->{mgmtip};
   ## 
   ## If the queue is clear, enqueue execute of SNMP Dispatcher at end of the queue
   ##
   unless (scalar keys %{$queue}) { $poe_kernel->yield("execute"); }
   ##
   ## Check if msgs for IP are already enqueued. queue values are anonymous arrays. 
   ## requests to the same IP will be grouped in the anon. array. 
   ##
   ## The msg will flag whether polling to a device is serial or parallel. Switches
   ## don't like parallel polls to Fdbtables. 
   ##
   unless (defined($queue->{$mgmtip})) { 
      $queue->{$mgmtip} = [];
      push(@$order, $mgmtip);
   } 
   my $qnode = $queue->{$mgmtip};
   push(@$qnode, $msg);
} 

##
## This process takes messages from the queue and ca;;s _request to
## create the Net::SNMP request.
##
sub _dequeue {
   my $self = shift;
   my $queue = $self->{queue};
   my $order = $self->{order};
   my $sesscnt = 0;
   my $ordcnt  = 0;
   ##
   ## Get qnode from queue based on FIFO of @$order
   ##
   while ($sesscnt < $self->{maxsess} && $#$order >= $ordcnt) {
      my $mgmtip = $order->[$ordcnt];	# @$order has the FIFO of mgmtip
      my $qnode = $queue->{$mgmtip};    # %$queue contains qnodes ([$msg]) keyed by mgmtip
      my $msg;
      ##
      ## Process entries from qnode. If message is not concurrent, leave other messages
      ## in qnode for later processing.
      ##
      while ($msg = shift(@$qnode)) {
         $sesscnt++;
         $self->_request($msg);
         my $args = $msg->dstargs;
         last unless defined($args->{concurrent});
         last unless $sesscnt < $self->{maxsess};
      }
      ##
      ## Move on to next entry in queue or enqueue next nodes entry for this IP
      ## If qnode is not empty, increment $ordcnt 
      ## splice out mgmtip of qnode if qnode empty and delete from queue
      ##
      if ($#$qnode > -1) {
         $ordcnt++;
      } else {
         splice(@$order, $ordcnt, 1);
         delete $queue->{$mgmtip};
      }
   }
}

sub _request {
   my $self = shift;
   my $msg  = shift; 
   ##
   my $args = $msg->dstargs;
   my $handler = $args->{_msghndlr};
   my $sender  = $args->{_msgsndr};
   my $state   = $args->{state};
   ##
   my $tm = defined($args->{timeout}) ? $args->{timeout} : $self->{timeout};
   my $rtry = defined($args->{retry}) ? $args->{retry} : $self->{retry};
   my $RO = defined($args->{rovar}) ? $args->{rostr} . '@' . $args->{rovar} : $args->{rostr};
   my ($SNMPsession, $error) = Net::SNMP->session(
       -hostname     => $args->{mgmtip},
       -community    => $RO,
       -version      => 'snmpv2c',
       -port         => $args->{port},
       -timeout      => $tm,
       -nonblocking  => 1,
       -retries      => $rtry
   );
      if (!defined($SNMPsession)) {
         printf("ERROR: %s.\n", $error);
         exit 1;
      }
   ##
   ## $sess_mib->{SNMPsession}->{} used to store partial getbulk returns until compelte
   ## TODO Message->args can be used for storing mib collection
   ##
   my $callback = [\&_handler, $self, $sender, $msg, $handler];
   if ($state eq "get") {
      $SNMPsession->get_request(
         -callback       => $callback,
         -varbindlist    => [$args->{oid}]
      );
   }
   ##
   ## TODO Make this do something
   ##
   if ($state eq "getnext") {
      $SNMPsession->get_next_request(
         -callback       => $callback,
         -varbindlist    => [$args->{oid}]
      );
   }
   if ($state eq "getbulk") {
      my $mxrep = defined($args->{maxrep}) ? $args->{maxrep} : $self->{maxrepetitions};
      $SNMPsession->get_bulk_request(
         -callback       => $callback,
         -maxrepetitions => $mxrep,
         -varbindlist    => [$args->{oid}]
      );
   }
}



1;
