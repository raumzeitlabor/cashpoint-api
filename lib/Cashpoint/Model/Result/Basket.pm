package Cashpoint::Model::Result::Basket;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('basket');
__PACKAGE__->add_columns(
    basketid => {
        accessor  => 'basket',
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

    date => {
        data_type => 'datetime',
        is_nullable => 0,
    },
);

sub value {
    my $self = shift;
    return $self->search_related('BasketItems', undef)->get_column('price')->sum || 0,
}

sub items {
    my $self = shift;
    return $self->search_related('BasketItems', undef)->count;
}

__PACKAGE__->set_primary_key('basketid');
__PACKAGE__->has_many('BasketItems' => 'Cashpoint::Model::Result::BasketItem', 'basketid');
__PACKAGE__->has_one('Cashcard' => 'Cashpoint::Model::Result::Cashcard', 'cardid');
__PACKAGE__->belongs_to('cardid' => 'Cashpoint::Model::Result::Cashcard');

42;
