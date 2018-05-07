package BinaryCodec;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use Fcntl qw(:seek);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   =
  qw(delta_varint_list_encode delta_varint_list_decode);

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

sub varint_decode($) {
    ## List of bytes => integer, bytes read
    my $bytes = shift;
    my ($i, $value) = (0, 0);

    for (my ($byte, $shift) = (0, 0);; ++$i, $shift += 7) {
        $byte = $bytes->[$i];
        my $last_byte = !($byte & 0x80);
        $byte &= ~0x80;
        $value += $byte << $shift;
        last if $last_byte;
    }

    return $value, $i + 1;
}

sub consume_varint($) {
    ## List of bytes => integer, shorter list of bytes
    my $ints = shift;

    my ($n, $bytes_read) = varint_decode $ints;
    splice @$ints, 0, $bytes_read;
    return $n, $ints;
}

sub delta_varint_list_decode($) {
    my $ints = shift;
    die sprintf "Bad header byte \`%02x', expected 0x04.\n"
      unless $ints->[0] == 4;
    shift @$ints;

    my @out = ();
    my $last_n = 0;
    while (@$ints > 0) {
        my ($n, $ints) = consume_varint $ints;
        $last_n += $n;
        push @out, $last_n;
    }
    return @out;
}
