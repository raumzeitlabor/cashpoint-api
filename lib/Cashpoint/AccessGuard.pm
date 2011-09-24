package Cashpoint::AccessGuard;

use strict;
use warnings;

use Exporter 'import';
use Dancer ':syntax';
use Log::Log4perl qw( :easy );

our @EXPORT = qw/protected/;

sub protected {
    my ($level, $sub, @args) = @_;

    return sub {
        # check for auth_token
        unless (Cashpoint::Context->get('sessionid')) {
            WARN 'request not authorized, refusing to answer';
            return status(401);
        }

        # $level is optional, so check if $cb moved one arg slot
        if (ref $level eq 'CODE') {
            unshift @args, $sub;
            $sub = $level;
        } else {
            if (Cashpoint::Context->get('role') ne $level) {
                WARN 'valid session but wrong role, refusing to answer request';
                return status(403);
            }
        }

        return &$sub(@args);
    }
}

42;
