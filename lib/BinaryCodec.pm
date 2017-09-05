package BinaryCodec;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use Fcntl qw(:seek);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   =
  qw(delta_varint_list_encode);

%EXPORT_TAGS = (all => \@EXPORT_OK,);

## CSV list of non-negative integers => blob
sub delta_varint_list_encode($) {
    my @strings = split /,\s*/, shift;
    my @ints = map { die "Bad integer \`$_'" unless /^\d+$/; 0 + $_; } @strings;

    use Data::Dumper; print STDERR Dumper(\@ints);
    return '';
}
