package Cashpoint::Model::Result::Credit;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('credit');
__PACKAGE__->add_columns(
    creditid => {
        accessor  => 'credit',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    cashcardid => {
        accessor => 'cashcard',
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 0,
    },

    saleid => {
        accessor => 'sale',
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 1,
    },

    # 0 = init (transition)
    # 1 = cash
    # 2 = transaction
    # 3 = transfer
    chargingtype => {
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 0,
    },

    remark => {
        data_type => 'varchar',
        size      => 50,
        is_nullable => 1,
    },

    date => {
        data_type => 'datetime',
        timezone => 'local',
        is_nullable => 0,
    },

    amount => {
        data_type => 'float',
        is_numeric => 1,
        is_nullable => 0,
    },

    balance => {
        data_type => 'float',
        is_numeric => 1,
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('creditid');
__PACKAGE__->belongs_to('cashcardid' => 'Cashpoint::Model::Result::Cashcard');

1;
