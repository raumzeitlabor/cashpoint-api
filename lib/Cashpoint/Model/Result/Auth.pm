package Cashpoint::Model::Result::Auth;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('auth');
__PACKAGE__->add_columns(
    authid => {
        accessor  => 'auth',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    userid => {
        accessor => 'user',
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 1,
    },

    code => {
        data_type   => 'varchar',
        size        => 18,
        is_nullable => 1,
    },

    cashcardid => {
        accessor    => 'cashcard',
        data_type   => 'id',
        is_nullable => 1,
    },

    username => {
        data_type   => 'varchar',
        size        => 30,
        is_nullable => 1,
    },

    token => {
        data_type   => 'varchar',
        size        => 16,
        is_nullable => 1,
    },

    # 1 = PIN, 2 = USER/PW
    auth_mode => {
        data_type => 'integer',
        is_nullable => 0,
    },

    login_date => {
        data_type => 'datetime',
        is_nullable => 0,
    },

    last_action => {
        data_type => 'datetime',
        is_nullable => 1,
    },
);

__PACKAGE__->set_primary_key('authid');
__PACKAGE__->belongs_to('cashcardid', 'Cashpoint::Model::Result::Cashcard');

42;
