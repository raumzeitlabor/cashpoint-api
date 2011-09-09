package BenutzerDB::Auth;

use strict;
use warnings;

use Exporter 'import';

use Data::Dumper;
use Crypt::SaltedHash;
use Dancer::Plugin::Database;

our @EXPORT = qw/auth_by_passwd auth_by_pin/;

sub auth_by_passwd {
    my ($username, $passwd) = @_;

    my $user = database->quick_select('nutzer', { handle => $username });

    if (!defined $user || !Crypt::SaltedHash->validate($user->{passwort}, $passwd)) {
        return undef;
    }

    return $user->{id};
};

sub auth_by_pin {
    my ($userid, $pin) = @_;

    my $user = database->quick_select('nutzer', {
        id  => $userid,
        pin => $pin,
    });

    return $user->{id} ? $user->{id} : undef;
};

42;
