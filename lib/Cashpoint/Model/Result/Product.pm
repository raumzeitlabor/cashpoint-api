package Cashpoint::Model::Result::Product;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

use Cashpoint::Model::Price;
use Dancer::Plugin::DBIC;

use POSIX qw(ceil);

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

    stock => {
        data_type => 'integer',
        is_numeric => 1,
        is_nullable => 0,
        default_value => \'0',
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

sub price {
    my ($self, $cashcard, $quantity) = @_;

    # if no quantity was applied, we assume a qty of 0
    $quantity ||= 0;

    # if no conditions have been explicitly defined for this product, there
    # may be a default condition for the group of the user, so we also look
    # for it. however, these conditions have lower priority than product
    # conditions.
    my $parser = schema->storage->datetime_parser;
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
            -or => [
                quantity => { '>=', $quantity },
                quantity => undef,
            ],
            startdate => { '<=', $parser->format_datetime(DateTime->now) },
            -or => [
                enddate => { '>=', $parser->format_datetime(DateTime->now) },
                enddate => undef,
            ],
        ],
    }, {
        order_by => { -desc => qw/productid groupid userid quantity/ },
    }); # FIXME: with valid date

    return undef unless $conditions->count;

    # FIXME: use weighted average?
    my $base = $self->search_related('Purchases', {
    }, {
        #+select  => [ \'me.price/me.amount' ], # FIXME: is there a more elegant way?
        #+as      => [ qw/unitprice/ ],
        order_by => { -desc => 'purchaseid' },
        rows     => 5,
    })->get_column('price')->func('AVG');

    # FIXME: calculate prices for all conditions and cache them?
    # prices are always rounded up to the tenth digit for moar profit
    while (my $c = $conditions->next) {
        if (0) {
        } elsif ($c->premium && $c->fixedprice) {
            return Cashpoint::Model::Price->new($c->id, sprintf("%.1f0",
                ceil(($base*$c->premium+$c->fixedprice)/0.1)*0.1));
        } elsif ($c->premium && !$c->fixedprice) {
            return Cashpoint::Model::Price->new($c->id, sprintf("%.1f0",
                ceil($base*$c->premium/0.1)*0.1));
        } elsif (!$c->premium && $c->fixedprice) {
            return Cashpoint::Model::Price->new($c->id, sprintf("%.1f0",
                ceil($c->fixedprice/0.1)*0.1));
        }
        return undef;
    }
};

__PACKAGE__->set_primary_key('productid');
__PACKAGE__->has_many('Purchases' => 'Cashpoint::Model::Result::Purchase',
    'productid', { order_by => { -desc => 'purchaseid' }});
__PACKAGE__->has_many('SaleItems' => 'Cashpoint::Model::Result::SaleItem',
    'productid', { order_by => { -desc => 'itemid' }});
__PACKAGE__->has_many('Conditions' => 'Cashpoint::Model::Result::Condition',
    'productid', { order_by => { -desc => [qw/userid groupid/]}});

42;
