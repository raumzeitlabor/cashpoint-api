#!/usr/bin/perl

package Cashpoint::Model::Result::Sale;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('sale');
__PACKAGE__->add_columns(
    saleid => {
        accessor  => 'sale',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    cashcardid => {
        accessor => 'cashcard',
        data_type => 'integer',
        is_nullable => 0,
    },

    basketdate => {
        data_type => 'datetime',
        is_nullable => 1,
    },

    saledate => {
        data_type => 'datetime',
        is_nullable => 0,
    },

    total => {
        data_type => 'float',
        is_numeric => 1,
        is_nullable => 0,
    },

);

__PACKAGE__->set_primary_key('saleid');
__PACKAGE__->has_many('SaleItems' => 'Cashpoint::Model::Result::SaleItem', 'itemid');
__PACKAGE__->belongs_to('cashcardid' => 'Cashpoint::Model::Result::Cashcard');

1;
