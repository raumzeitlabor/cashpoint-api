package Cashpoint::Model::Result::CompositeProduct;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

my $product_class = 'Cashpoint::Model::Result::Product';

__PACKAGE__->table('compositeproduct');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    compositeid => {
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

# we want to behave like a "normal" product
sub inflate_result {
    my $self = shift;
    my $ret = $self->next::method(@_);
    $self->ensure_class_loaded($product_class);
    bless $ret, $product_class;
    return $ret;
}

42;
