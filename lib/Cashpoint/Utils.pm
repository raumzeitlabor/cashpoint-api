package Cashpoint::Utils;

use strict;
use warnings;

use Exporter 'import';
use Algorithm::CheckDigits;

use Cashpoint::Context;

our @EXPORT_OK = qw/generate_token validate_ean/;

my $ean_validator = CheckDigits('ean');

sub validate_ean {
   return $ean_validator->is_valid(shift);
}

sub generate_token {
    return join("", map { ('a'..'z','A'..'Z',0..9)[rand 62] } (1..20));
}

42;
