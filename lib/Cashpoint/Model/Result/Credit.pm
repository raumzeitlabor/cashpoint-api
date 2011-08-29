#!/usr/bin/perl

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

    cardid => {
        accessor => 'card',
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

    chargingtype => {
        data_type => 'integer', # 0 = init (transition), 1 = cash, 2 = transaction
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
        is_nullable => 0,
    },

    amount => {
        accessor => '_amount',
        data_type => 'float',
        is_numeric => 1,
        is_nullable => 0,
    },
);

sub amount {
    my $self = shift;
    return $self->_amount(@_) if @_;
    return sprintf("%.2f", $self->_amount());
}

__PACKAGE__->set_primary_key('creditid');
__PACKAGE__->belongs_to('cardid' => 'Cashpoint::Model::Result::Cashcard');

1;
