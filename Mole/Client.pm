#!/usr/bin/perl
package Mole::Client;
$MID = 0;
use warnings;
use strict;
our $ALIAS = "molec2localhost";
use POE;
use POE::Filter::Reference;
use POE::Component::Client::TCP;
use Mole::Message;
my $debug = 0;
my $count = 0;
##
##
##
##
sub new {
   my $package = shift;
   my $self = {};
   bless $self, $package;
   return $self;
}

sub spawn {
   my $package = shift;
   my $self = $package->new(@_);

   printf("%s::spawn \n", ref($self)) if $debug;
   POE::Component::Client::TCP->new
     ( #Alias => $ALIAS,
       ##
       ##
       ##
       RemoteAddress => "localhost",
       RemotePort    => 4269,
       #Filter        => ["POE::Filter::Reference", "YAML"],
       Filter        => ["POE::Filter::Reference"],
       ##
       ##
       ##
       Started   => sub {
          my ($heap, $session, $self) = @_[HEAP, SESSION, OBJECT];
          $poe_kernel->alias_set($ALIAS);
          printf("%s::Started ID %s\n", ref($self), $session->ID); # if $debug;

       },
       ##
       ##
       ##
       Connected => sub {
          my ($heap, $session, $self) = @_[HEAP, SESSION, OBJECT];
          $heap->{tcpstatus} = 1;
          printf("%s::Connected %s\n", ref($self),$heap->{tcpstatus});# if $debug;
          my $message;
          foreach my $key (keys %{$heap}) {
             printf("%s::Connected %s\t%s\n", ref($self), $key, $heap->{$key}) if $debug;
          }
       },
       ##
       ## Receive a response, display it, and shut down the client.
       ##
       ServerInput => sub {
           my ( $kernel, $msg) = @_[ KERNEL, ARG0 ];
           #printf("REF=%s\n", ref($msg));
           if (ref($msg) eq 'SCALAR') {
              printf("%s::ServerInput MSG Object returned: %s\n", 'Mole::Client', $$msg);
              $kernel->yield("shutdown");
   
           }
           if (ref($msg) eq 'ARRAY') {
              printf("MID=%s\tVAL=%s\n", $msg->[0], $msg->[1]);
           }
   
           if (ref($msg) eq 'Mole::Message') {
              $msg->debug('Mole::Client::ServerInput') if $debug;
              $kernel->post($msg->dstsess, $msg->dstevent, $msg);
              $count--;
              if ($count == 0) {
                 $kernel->yield("shutdown");
              }
           }
   
       },
       ##
       ##
       ##
       Disconnected => sub {
          my ( $kernel, $heap ) = @_[KERNEL, HEAP];
          $heap->{tcpstatus} = 0;
          printf("%s::Disconnected %s\n", ref($self), $heap->{tcpstatus});# if $debug;
          #$kernel->yield("shutdown");
       },
       InlineStates => { 'send' => sub {
          my ($kernel, $heap, $msg, $session ) = @_[KERNEL, HEAP, ARG0, SESSION];
		# Foo is a connected bit TODO expand functionality and
		# make robust.
              if ($heap->{tcpstatus} == 1) {
                #printf("%s::send MSG=%s\n", ref($self), ref($msg));# if $debug;
                $heap->{server}->put( $msg );
                $count++;
             } else {
                if ($heap->{tcpstatus} == 0) {
                   $kernel->call($session, "reconnect");
                   $heap->{tcpstatus} = -1;
                }
                # printf("%s::send -DELAY- MSG=%s\n", ref($self), ref($msg));# if $debug;
                $kernel->delay_set('send', 60, $msg);
             }
          },
       },
     );
}

#sub send {
#   my ( $kernel, $heap, $msg ) = @_[KERNEL, HEAP, ARG0];
#   $heap->{server}->put( $msg );
#}

sub getmid {
   $main::MID++;
   return $main::MID;
} 
1;
