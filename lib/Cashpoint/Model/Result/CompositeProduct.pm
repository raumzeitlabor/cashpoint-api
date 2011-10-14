package Cashpoint::Model::Result::CompositeProduct;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table('compositeproduct');
__PACKAGE__->add_columns(
    compositeid => {
        accessor  => 'composite',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    productid => {
        accessor => 'product',
        data_type => 'integer',
        is_nullable => 0,
    },

    units => {
        data_type => 'integer',
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('compositeid');
__PACKAGE__->has_many('Products', 'Cashpoint::Model::Result::Product', 'productid');

42;
