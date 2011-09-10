package Cashpoint::AuthGuard;

use strict;
use warnings;

use Exporter 'import';
use Data::Dumper;

use Dancer ':syntax';

our @EXPORT = qw/authenticated/;

sub authenticated {
    my ($level, $sub, @args) = @_;

    return sub {
        # check for auth_token
        return status(401) unless Cashpoint::Context->get('token');

        # $level is optional, so check if $cb moved one arg slot
        if (ref $level eq 'CODE') {
            unshift @args, $sub;
            $sub = $level;
        } else {
            return status(403) if Cashpoint::Context->get('role') ne $level;
        }

        return &$sub(@args);
    }
}
