#!/usr/bin/perl

package Cashpoint::Model::Result::Cashcard;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('cashcard');
__PACKAGE__->add_columns(
    cashcardid => {
        accessor  => 'card',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    code => {
        data_type => 'varchar',
        size      => 18,
        is_nullable => 0,
    },

    groupid => {
        accessor => 'group',
        data_type => 'integer',
        is_nullable => 0,
    },

    userid => {
        accessor => 'user',
        data_type => 'integer',
        is_nullable => 1,
    },

    activationdate => {
        data_type => 'datetime',
        is_nullable => 0,
    },

    disabled => {
        data_type => 'boolean',
        default_value => 0,
    },
);

sub credit {
    my $self = shift;
    my $credit = $self->search_related('Credit', {});
    return sprintf("%.2f", ($credit->count ? $credit->get_column('amount')->sum : 0) +0.0);
}

__PACKAGE__->set_primary_key('cashcardid');
__PACKAGE__->has_many('Credit' => 'Cashpoint::Model::Result::Credit', 'cashcardid');
__PACKAGE__->belongs_to('groupid' => 'Cashpoint::Model::Result::Group');

42;
