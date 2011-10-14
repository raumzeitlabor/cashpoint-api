package Cashpoint::Model::Result::CompositeProduct;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table('compositeproduct');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    compositeid => {
        accessor => 'composite',
        data_type => 'integer',
        is_nullable => 0,
    },

    units => {
        data_type => 'integer',
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_one(product => 'Cashpoint::Model::Result::Product', {
    'foreign.productid' => 'self.compositeid'
});

42;
