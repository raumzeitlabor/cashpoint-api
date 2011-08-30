package Cashpoint::Model::Result::Purchase;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('purchase');
__PACKAGE__->add_columns(
    purchaseid => {
        accessor  => 'purchase',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    productid => {
        accessor => 'product',
        data_type => 'integer',
        is_nullable => 0,
    },

    userid => {
        accessor => 'user',
        data_type => 'integer',
        is_nullable => 0,
    },

    supplier => {
        data_type => 'varchar',
        is_nullable => 0,
        size => 30,
    },

    purchasedate => {
        data_type => 'date',
        is_nullable => 0,
    },

    expirydate => {
        data_type => 'date',
        is_nullable => 1,
    },

    amount => {
        data_type => 'integer',
        is_nullable => 0,
    },

    price => {
        data_type => 'float',
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('purchaseid');
__PACKAGE__->belongs_to('productid' => 'Cashpoint::Model::Result::Product');

1;
