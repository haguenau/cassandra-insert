package BinaryCodec;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use Fcntl qw(:seek);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   =
  qw(delta_varint_list_encode
     delta_varint_list_encode_csv_magic
     delta_varint_list_encode_length
     delta_varint_list_decode);

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

## Integer list => delta-encoded varint blob (no length, no header).
sub delta_varint_list_encode($) {
    my $segments = shift;
    my @sorted = sort { $a <=> $b }
      map { die "Bad integer \`$_'" unless /^\d+$/; 0 + $_; } @$segments;

    my $out = '';
    my $prev = 0;
    for my $n (@sorted) {
        my $delta = $n - $prev;
        $out .= varint_encode_single $delta if $delta > 0 || length $out == 1;
        $prev = $n;
    }

    return $out;
}

## CSV list of non-negative integers => blob
## Format is the one shared through ScyllaDB by data and backend:
## just integers, preceded by an encoding type byte with value 4.
sub delta_varint_list_encode_csv_magic($) {
    my @segments = split /,\s*/, shift;
    my $magic_byte_blob = pack 'C', 0x4;
    my $segments_blob = delta_varint_list_encode \@segments;

    return $magic_byte_blob . $segments_blob;
}

## Integer list => blob
## Format is all varints, the first one indicating the length of the list.
## This is the format shared through Segvault between data and backend.
sub delta_varint_list_encode_length($) {
    my $ints = shift;
    my $length_blob = varint_encode_single(scalar @$ints);
    my $segments_blob = delta_varint_list_encode $ints;

    return $length_blob . $segments_blob;
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
