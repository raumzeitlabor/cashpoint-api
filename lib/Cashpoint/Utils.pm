use strict;
use warnings;

use Exporter 'import';
use Algorithm::CheckDigits;

our @EXPORTS = qw/validate_ean/;
our @EXPORTS_OK = qw/generate_token/;

my $ean_validator = CheckDigits('ean');

sub validate_ean {
   return $ean_validator->is_valid(shift);
}

sub generate_token {
    return join("", map { ('a'..'z','A'..'Z',0..9)[rand 62] } (1..20));
}

42;

