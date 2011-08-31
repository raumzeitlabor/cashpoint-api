package Cashpoint::Model::Result::Product;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

use Cashpoint::API::Pricing::Engine;
use Dancer::Plugin::DBIC;

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('product');
__PACKAGE__->add_columns(
    productid => {
        accessor  => 'product',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
    },

    ean => {
        data_type => 'varchar',
        is_nullable => 0,
        size => 20,
    },

    name => {
        data_type => 'varchar',
        is_nullable => 0,
        size => 30,
    },

    threshold => {
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 0,
        default_value => \'0',
    },

    added_on => {
        data_type => 'datetime',
        is_nullable => 0,
    },
);

sub stock {
    my $self = shift;
    return $self->search_related('Purchases', {})->get_column('amount')->sum || 0;
};

sub price {
    my ($self, $cashcard) = @_;

    # if no conditions have been explicitly defined for this product, there
    # may be a default condition for the group of the user, so we also look
    # for them. however, these conditions have lower priority than product
    # conditions.
    my $conditions = schema->resultset('Condition')->search({
        -and => [
            -or => [
                productid => $self->id,
                productid => undef,
            ],
            -or => [
                userid => $cashcard->user,
                userid => undef,
            ],
            groupid => $cashcard->group->id,
        ],
    }, {
        order_by => { -desc => [qw/productid userid groupid/] }
    }); # FIXME: with valid date

    return undef unless $conditions->count;

    my $base = $self->search_related('Purchases', {}, {
        order_by => { -desc => 'purchaseid' },
        rows     => 5,
    })->get_column('price')->func('AVG');
    while (my $c = $conditions->next) {
        if (0) {
        } elsif ($c->premium && $c->fixedprice) {
            return sprintf("%.2f", $base*$c->premium+$c->fixedprice);
        } elsif ($c->premium && !$c->fixedprice) {
            return sprintf("%.2f", $base*$c->premium);
        } elsif (!$c->premium && $c->fixedprice) {
            return sprintf("%.2f", $c->fixedprice);
        }
        return 0;
    }
};

__PACKAGE__->set_primary_key('productid');
__PACKAGE__->has_many('Purchases' => 'Cashpoint::Model::Result::Purchase', 'productid');
__PACKAGE__->has_many('SaleItems' => 'Cashpoint::Model::Result::SaleItem', 'productid');
__PACKAGE__->has_many('Conditions' => 'Cashpoint::Model::Result::Condition', 'productid');

1;
