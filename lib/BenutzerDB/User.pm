package BenutzerDB::User;

use strict;
use warnings;

use Exporter 'import';

use Data::Dumper;
use Dancer::Plugin::Database;

our @EXPORT = qw/get_user/;

sub get_user {
    my $userid = shift;

    # check if connection to benutzerdb is alive
    eval { database; }; return undef if $@;

    my $user = database->quick_select('nutzer', { id => $userid });

    return {
        userid   => $user->{id},
        username => $user->{handle},
        realname => $user->{realname},
        email    => $user->{email},
    } if defined $user;

    return undef;
}

42;
