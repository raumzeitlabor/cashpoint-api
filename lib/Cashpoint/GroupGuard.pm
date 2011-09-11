package Cashpoint::GroupGuard;

use strict;
use warnings;

use Exporter 'import';
use Data::Dumper;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::REST;

our @EXPORT = qw/valid_group/;

sub valid_group {
    my ($sub, @args) = @_;

    return sub {
        my ($groupid) = splat;
        my $group = schema('cashpoint')->resultset('Group')->find($groupid);
        return status_not_found('group not found') unless $group;
        return &$sub($group, @args);
    }
}
