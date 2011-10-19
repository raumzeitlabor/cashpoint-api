package Cashpoint::Utils;

use strict;
use warnings;

use Exporter 'import';
use Algorithm::CheckDigits;

use Cashpoint::Context;

our @EXPORT_OK = qw/generate_token validate_ean generate_ean/;

my $ean_validator = CheckDigits('ean');

sub validate_ean {
    return $ean_validator->is_valid(shift);
}

# generates a valid ean13 (with a fixed '2342' prefix)
sub generate_ean {
    my @valid = (0..9);
    my @data = map { $valid[rand 10] } (1..8);
    my $ean = "2342".join("", @data);
    return $ean_validator->complete($ean);
}

sub generate_token {
    return join("", map { ('a'..'z','A'..'Z',0..9)[rand 62] } (1..20));
}

42;
