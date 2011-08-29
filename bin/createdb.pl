#!/usr/bin/perl

use strict;
use warnings;

use Dancer;
use Dancer::Plugin::DBIC;
use Cashpoint::Model;

schema->deploy({ add_drop_table => 1});
