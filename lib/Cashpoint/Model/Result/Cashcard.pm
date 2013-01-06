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

    pin => {
        data_type => 'varchar',
        size      => 6,
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
        timezone => 'local',
        is_nullable => 0,
    },

    disabled => {
        data_type => 'boolean',
        default_value => 0,
    },
);

sub balance {
    my $self = shift;
    my $credit = $self->search_related('Credit', {}, {
        select   => qw/balance/,
        order_by => { -desc => 'creditid' },
        rows     => 1,
    });

    return ($credit->count ? $credit->first->get_column('balance') : 0);
}

sub transfer {
    my ($self, $recipient, $amount, $reason) = @_;

    $self->result_source->schema->txn_do(sub {
        $self->create_related('Credit', {
            chargingtype => 3,
            amount       => - $amount,
            date         => DateTime->now(time_zone => 'local'),
            balance      => $self->balance - $amount,
            remark       => $reason,
        });

        my $recipientcard = $self->result_source->schema->resultset('Cashcard')->find({
            code => $recipient,
        });

        $self->result_source->schema->txn_rollback unless $recipientcard;

        $recipientcard->create_related('Credit', {
            chargingtype => 3,
            amount       => $amount,
            date         => DateTime->now(time_zone => 'local'),
            balance      => $recipientcard->balance + $amount,
            remark       => $reason,
        });
    });

    die $@ if $@;
}

sub transfers {
    my $self = shift;

    my $transfers = $self->search_related("Credit", {
        chargingtype => 3
    }, {
        order_by => { -desc => "creditid" },
    });

    my @data = ();
    while (my $t = $transfers->next) {
        push @data, {
            remark => $t->remark,
            date   => $t->date->datetime,
            amount => $t->amount,
        };
    }

    return @data;
};

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    $sqlt_table->add_index(name => 'codeindex', fields => ['code']);
}

__PACKAGE__->set_primary_key('cashcardid');
__PACKAGE__->has_many('Credit' => 'Cashpoint::Model::Result::Credit', 'cashcardid');
__PACKAGE__->belongs_to('groupid' => 'Cashpoint::Model::Result::Group');

42;
