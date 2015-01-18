#!/usr/bin/perl

use strict;

use Net::SNMP qw(:snmp);

my ($session, $error) = Net::SNMP->session(
   -version     => 'snmpv2c',
   -nonblocking => 1,
   -hostname    => shift || '10.145.161.1',
   -community   => shift || 'password',
   -port        => shift || 161 
);

if (!defined($session)) {
   printf("ERROR: %s.\n", $error);
   exit 1;
}

#my $ifTable = '1.3.6.1.2.1.2.2';
my $ifTable = '1.3.6.1.2.1.1';

my $result = $session->get_bulk_request(
   -callback       => [\&table_cb, {}],
   -maxrepetitions => 10,
   -varbindlist    => [$ifTable]
);

if (!defined($result)) {
   printf("ERROR: %s.\n", $session->error);
   $session->close;
   exit 1;
}

snmp_dispatcher();

$session->close;

exit 0;

sub table_cb
{
   my ($session, $table) = @_;

   if (!defined($session->var_bind_list)) {

      printf("ERROR: %s\n", $session->error);   

   } else {

      # Loop through each of the OIDs in the response and assign
      # the key/value pairs to the anonymous hash that is passed
      # to the callback.  Make sure that we are still in the table
      # before assigning the key/values.

      my $next;

      foreach my $oid (oid_lex_sort(keys(%{$session->var_bind_list}))) {
         if (!oid_base_match($ifTable, $oid)) {
            $next = undef;
            last;
         }
         $next = $oid; 
         $table->{$oid} = $session->var_bind_list->{$oid};   
      }

      # If $next is defined we need to send another request 
      # to get more of the table.

      if (defined($next)) {
         printf("WHACK!\n");
         $result = $session->get_bulk_request(
            -callback       => [\&table_cb, $table],
            -maxrepetitions => 10,
            -varbindlist    => [$next]
         ); 

         if (!defined($result)) {
            printf("ERROR: %s\n", $session->error);
         }

      } else {

         # We are no longer in the table, so print the results.

         foreach my $oid (oid_lex_sort(keys(%{$table}))) {
            printf("%s => %s\n", $oid, $table->{$oid});
         }

      }
   }
}
