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

sub varint_encode_single($) {
    my $n = shift;
    return pack 'C', 0 if $n == 0;
    die "This integer is too big: \`$n'" if $n > (1 << 63);

    my @out = ();
    while ($n > 0) {
        push @out, (($n > 127 ? 0x80 : 0x00) | ($n & 0x7f));
        $n >>= 7;
    }

    return pack 'C*', @out;
}

## CSV list of non-negative integers => blob
sub delta_varint_list_encode($) {
    my @strings = split /,\s*/, shift;
    my @ints = sort { $a <=> $b }
      map { die "Bad integer \`$_'" unless /^\d+$/; 0 + $_; } @strings;
    my $magic_byte = 0x4;

    my $out = '';
    $out .= pack 'C', $magic_byte;

    my $prev = 0;
    for my $n (@ints) {
        $out .= varint_encode_single $n - $prev;
        $prev = $n;
    }

    return $out;
}
