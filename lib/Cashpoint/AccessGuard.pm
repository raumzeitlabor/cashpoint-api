package Cashpoint::AccessGuard;

use strict;
use warnings;

use Exporter 'import';
use Data::Dumper;

use Dancer ':syntax';

our @EXPORT = qw/protected/;

sub protected {
    my ($level, $sub, @args) = @_;

    return sub {
        # check for auth_token
        return status(401) unless Cashpoint::Context->get('authid');

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

42;
