package Cashpoint::Model::Result::Condition;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;
use Log::Log4perl qw( :easy );
use POSIX qw(ceil);

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->table('condition');
__PACKAGE__->add_columns(
    conditionid => {
        accessor  => 'condition',
        data_type => 'integer',
        is_nullable => 0,
        is_auto_increment => 1,
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

    productid => {
        accessor  => 'product',
        data_type => 'integer',
        is_nullable => 1,
    },

    quantity => {
        data_type => 'integer',
        is_nullable => 1,
        is_numeric => 1,
    },

    comment => {
        data_type => 'varchar',
        size      => 50,
        is_nullable => 1,
    },

    premium => {
        data_type => 'float',
        is_numeric => 1,
        is_nullable => 1,
    },

    fixedprice => {
        data_type => 'float',
        is_numeric => 1,
        is_nullable => 1,
    },

    startdate => {
        data_type => 'datetime',
        timezone => 'local',
        is_nullable => 0,
    },

    enddate => {
        data_type => 'datetime',
        timezone => 'local',
        is_nullable => 1,
    },

);

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    $sqlt_table->add_index(name => 'conditionindex', fields =>
        ['productid', 'groupid', 'userid', 'quantity', 'startdate', 'enddate']);
}

# returns true if this condition represents a fix price
sub is_fixed {
    my $self = shift;
    return (!$self->premium && $self->fixedprice);
}

# applies this condition to the given product
sub apply {
    my ($self, $product) = @_;
    my $base = $product->base;

    unless ($base) {
        WARN 'could not apply condition to product '.$product->name.' id ('
            .$product->product.' (could not determine base)';
        return undef;
    }

    if ($self->premium && $self->fixedprice) {
        DEBUG 'using PREMIUM&FIXEDPRICE mode for price calculation';
        my $val = $base*(1+$self->premium)+$self->fixedprice;
        return Cashpoint::Model::Price->new($self->id, sprintf("%.1f0",
            ceil($val/0.1)*0.1));
    } elsif ($self->premium && !$self->fixedprice) {
        DEBUG 'using PREMIUM mode for price calculation';
        my $val = $base*(1+$self->premium);
        return Cashpoint::Model::Price->new($self->id, sprintf("%.1f0",
            ceil($val/0.1)*0.1));
    } elsif (!$self->premium && $self->fixedprice) {
        DEBUG 'using FIXEDPRICE mode for price calculation';
        my $val = $self->fixedprice;
        return Cashpoint::Model::Price->new($self->id, sprintf("%.1f0",
            ceil($val/0.1)*0.1));
    }

    ERROR 'unknown pricing mode; invalid condition (id: '
        + $self->condition +')';

    return undef;
}

__PACKAGE__->set_primary_key('conditionid');
__PACKAGE__->belongs_to('productid' => 'Cashpoint::Model::Result::Product');
__PACKAGE__->belongs_to('groupid' => 'Cashpoint::Model::Result::Group');

42;
