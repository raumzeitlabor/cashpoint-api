package Cashpoint::Model::QueryLogger;

use strict;
use warnings;

use base 'DBIx::Class::Storage::Statistics';

use SQL::Beautify;
use Log::Log4perl qw( :easy );
use Time::HiRes qw(time);

my $start;
my $beautifier = SQL::Beautify->new;

sub query_start {
    my ($self, $sql, @params) = @_;
    $start = time();
}

sub print {
    my ($self, $msg) = @_;
    return if $self->silence;
    DEBUG $msg;
}

sub query_end {
    my ($self, $sql, @params) = @_;

    # replace placeholders with params
    foreach (@params) {
        $sql =~ s/\?/$_/;
    }

    my $beauty = $beautifier->query($sql);
    my $elapsed = sprintf("%0.4f", time() - $start);
    $self->print("Query ".$elapsed."s - ".$beauty);
    $start = undef;
}

42;
