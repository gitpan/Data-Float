=head1 NAME

Data::Float - details of the floating point data type

=head1 SYNOPSIS

	use Data::Float qw(have_signed_zero);

	if(have_signed_zero) { ...

	# and many other constants; see text

	use Data::Float qw(
		float_class float_is_normal float_is_subnormal
		float_is_nzfinite float_is_zero float_is_finite
		float_is_infinite float_is_nan
	);

	$class = float_class($value);

	if(float_is_normal($value)) { ...
	if(float_is_subnormal($value)) { ...
	if(float_is_nzfinite($value)) { ...
	if(float_is_zero($value)) { ...
	if(float_is_finite($value)) { ...
	if(float_is_infinite($value)) { ...
	if(float_is_nan($value)) { ...

	use Data::Float qw(float_sign float_parts float_hex);

	$sign = float_sign($value);
	($sign, $exponent, $significand) = float_parts($value);
	print float_hex($value);

	use Data::Float qw(pow2 mult_pow2 copysign nextafter);

	$x = pow2($exp);
	$x = mult_pow2($value, $exp);
	$x = copysign($value, $x);
	$x = nextafter($value, $x);

=head1 DESCRIPTION

This module is about the native floating point numerical data type.
A floating point number is one of the types of datum that can appear
in the numeric part of a Perl scalar.  This module supplies constants
describing the native floating point type, classification functions,
and functions to manipulate floating point values at a low level.

=head1 FLOATING POINT

Floating point values are divided into five subtypes:

=over

=item normalised

The value is made up of a sign bit (making the value positive or
negative), a significand, and exponent.  The significand is a number
in the range [1, 2), expressed as a binary fraction of a certain fixed
length.  (Significands requiring a longer binary fraction, or lacking a
terminating binary representation, cannot be obtained.)  The exponent
is an integer in a certain fixed range.  The magnitude of the value
represented is the product of the significand and two to the power of
the exponent.

=item subnormal

The value is made up of a sign bit, significand, and exponent, as
for normalised values.  However, the exponent is fixed at the minimum
possible for a normalised value, and the significand is in the range
(0, 1).  The length of the significand is the same as for normalised
values.  This is essentially a fixed-point format, used to provide
gradual underflow.  Not all floating point formats support this subtype.
Where it is not supported, underflow is sudden, and the difference between
two minimum-exponent normalised values cannot be exactly represented.

=item zero

Depending on the floating point type, there may be either one or two
zero values: zeroes may carry a sign bit.  Where zeroes are signed,
it is primarily in order to indicate the direction from which a value
underflowed (was rounded) to zero.  Positive and negative zero compare
as numerically equal, and they give identical results in most arithmetic
operations.  They are on opposite sides of some branch cuts in complex
arithmetic.

Beware that as of Perl 5.8.7 Perl will lose the sign of a zero for some
purposes if it is used in any arithmetic, including numerical comparisons.
Stringification of a zero is inconsistent in whether it shows the sign.

=item infinite

Some floating point formats include special infinite values.  These are
generated by overflow, and by some arithmetic cases that mathematically
generate infinities.  There are two infinite values: positive infinity
and negative infinity.

Perl does not always generate infinite values when normal floating point
behaviour calls for it.  For example, the division C<1.0/0.0> causes an
exception rather than returning an infinity.

=item not-a-number (NaN)

This type of value exists in some floating point formats to indicate
error conditions.  Mathematically undefined operations may generate NaNs,
and NaNs propagate through all arithmetic operations.  A NaN has the
distinctive property of comparing numerically unequal to all floating
point values, including itself.

Perl does not always generate NaNs when normal floating point behaviour
calls for it.  For example, the division C<0.0/0.0> causes an exception
rather than returning a NaN.

=back

=cut

package Data::Float;

use warnings;
use strict;

use Carp qw(croak);

our $VERSION = "0.003";

use base "Exporter";
our @EXPORT_OK = qw(
	float_class float_is_normal float_is_subnormal float_is_nzfinite
	float_is_zero float_is_finite float_is_infinite float_is_nan
	float_sign float_parts float_hex
	pow2 mult_pow2 copysign nextafter
);
# constant functions get added to @EXPORT_OK later

=head1 CONSTANTS

=head2 Features

=over

=item have_signed_zero

Boolean indicating whether floating point zeroes carry a sign.  If yes,
then there are two zero values: +0.0 and -0.0.  If no, then there is
only one zero value, considered unsigned.

=item have_subnormal

Boolean indicating whether there are subnormal floating point values.

=item have_infinite

Boolean indicating whether there are infinite floating point values.

=item have_nan

Boolean indicating whether there are NaN floating point values.

It is difficult to reliably generate a NaN in Perl, so in some unlikely
circumstances it is possible that there might be NaNs that this module
failed to detect.  In that case this constant would be false but a NaN
might still turn up somewhere.  What this constant reliably indicates
is the availability of the C<nan> constant below.

=back

=head2 Finite Extrema

=over

=item significand_bits

The number of fractional bits in the significand of finite floating
point values.

=item significand_step

The difference between adjacent representable values in the range [1, 2]
(where the exponent is zero).  This is equal to 2^-significand_bits.

=item max_finite_exp

The maximum exponent permitted for finite floating point values.

=item max_finite_pow2

The maximum representable power of two.  This is 2^max_finite_exp.

=item max_finite

The maximum representable finite value.  This is 2^(max_finite_exp+1)
- 2^(max_finite_exp-significand_bits).

=item max_integer

The maximum representable integral value.  This is 2^(significand_bits+1)
- 1.

=item min_normal_exp

The minimum exponent permitted for normalised floating point values.

=item min_normal

The minimum positive value representable as a normalised floating
point value.  This is 2^min_normal_exp.

=item min_finite_exp

The base two logarithm of the minimum representable positive finite value.
If there are subnormals then this is min_normal_exp - significand_bits.
If there are no subnormals then this is min_normal_exp.

=item min_finite

The minimum representable positive finite value.  This is
2^min_finite_exp.

=back

=head2 Special Values

=over

=item pos_zero

The positive zero value.  (Exists only if zeroes are signed, as indicated
by the C<have_signed_zero> constant.)

=item neg_zero

The negative zero value.  (Exists only if zeroes are signed, as indicated
by the C<have_signed_zero> constant.)

=item pos_infinity

The positive infinite value.  (Exists only if there are infinite values,
as indicated by the C<have_infinite> constant.)

=item neg_infinity

The negative infinite value.  (Exists only if there are infinite values,
as indicated by the C<have_infinite> constant.)

=item nan

Not-a-number.  (Exists only if NaN values were detected, as indicated
by the C<have_nan> constant.)

=back

=cut

sub mk_constant($$) {
	my($name, $value) = @_;
	no strict "refs";
	*{__PACKAGE__."::".$name} = sub () { $value };
	push @EXPORT_OK, $name;
}

#
# mult_pow2() multiplies a specified value by a specified power of two.
# This is done using repeated multiplication, and can cope with cases
# where the power of two cannot be directly represented as a floating
# point value.  (E.g., 0x1.b2p-900 can be multiplied by 2^1500 to get
# to 0x1.b2p+600; the input and output values can be represented in
# IEEE double, but 2^1500 cannot.)  Overflow and underflow can occur.
#
# @powtwo is an array such that powtwo[i] = 2^2^i.  Its elements are
# used in the repeated multiplication in mult_pow2.  Similarly,
# @powhalf is such that powhalf[i] = 2^-2^i.  Reading the exponent
# in binary indicates which elements of @powtwo/@powhalf to multiply
# by, except that it may indicate elements that don't exist, either
# because they're not representable or because the arrays haven't
# been filled yet.  mult_pow2() will use the last element of the array
# repeatedly in this case.  Thus array elements after the first are
# only an optimisation, and do not change behaviour.
#

my @powtwo = (2.0);
my @powhalf = (0.5);

sub mult_pow2($$) {
	my($value, $exp) = @_;
	return $_[0] if $value == 0.0;
	my $powa = \@powtwo;
	if($exp < 0) {
		$powa = \@powhalf;
		$exp = -$exp;
	}
	for(my $i = 0; $i != $#$powa && $exp != 0; $i++) {
		$value *= $powa->[$i] if $exp & 1;
		$exp >>= 1;
	}
	$value *= $powa->[-1] while $exp--;
	return $value;
}

#
# Range of finite exponent values.
#

my $min_finite_exp;
my $max_finite_exp;
my $max_finite_pow2;
my $min_finite;

my @directions = (
	{
		expsign => -1,
		powa => \@powhalf,
		xexp => \$min_finite_exp,
		xpower => \$min_finite,
	},
	{
		expsign => +1,
		powa => \@powtwo,
		xexp => \$max_finite_exp,
		xpower => \$max_finite_pow2,
	},
);

while(!$directions[0]->{done} || !$directions[1]->{done}) {
	foreach my $direction (@directions) {
		next if $direction->{done};
		my $lastpow = $direction->{powa}->[-1];
		my $nextpow = $lastpow * $lastpow;
		unless(mult_pow2($nextpow, -$direction->{expsign} *
					  (1 << (@{$direction->{powa}} - 1)))
				== $lastpow) {
			$direction->{done} = 1;
			next;
		}
		push @{$direction->{powa}}, $nextpow;
	}
}

foreach my $direction (@directions) {
	my $expsign = $direction->{expsign};
	my $xexp = 1 << (@{$direction->{powa}} - 1);
	my $extremum = $direction->{powa}->[-1];
	for(my $addexp = $xexp; $addexp >>= 1; ) {
		my $nx = mult_pow2($extremum, $expsign*$addexp);
		if(mult_pow2($nx, -$expsign*$addexp) == $extremum) {
			$xexp += $addexp;
			$extremum = $nx;
		}
	}
	${$direction->{xexp}} = $expsign * $xexp;
	${$direction->{xpower}} = $extremum;
}

mk_constant("min_finite_exp", $min_finite_exp);
mk_constant("min_finite", $min_finite);
mk_constant("max_finite_exp", $max_finite_exp);
mk_constant("max_finite_pow2", $max_finite_pow2);

#
# pow2() generates a power of two from scratch.  It complains if given
# an exponent that would make an unrepresentable value.
#

sub pow2($) {
	my($exp) = @_;
	croak "exponent $exp out of range [$min_finite_exp, $max_finite_exp]"
		unless $exp >= $min_finite_exp && $exp <= $max_finite_exp;
	return mult_pow2(1.0, $exp);
}

#
# Significand size.
#

my($significand_bits, $significand_step);
{
	my $i;
	for($i = 1; ; $i++) {
		my $tryeps = $powhalf[$i];
		last unless (1.0 + $tryeps) - 1.0 == $tryeps;
	}
	$i--;
	$significand_bits = 1 << $i;
	$significand_step = $powhalf[$i];
	while($i--) {
		my $tryeps = $significand_step * $powhalf[$i];
		if((1.0 + $tryeps) - 1.0 == $tryeps) {
			$significand_bits += 1 << $i;
			$significand_step = $tryeps;
		}
	}
}

mk_constant("significand_bits", $significand_bits);
mk_constant("significand_step", $significand_step);

my $max_finite = $max_finite_pow2 -
			pow2($max_finite_exp - $significand_bits - 1);
$max_finite += $max_finite;

my $max_integer = pow2($significand_bits + 1) - 1.0;

mk_constant("max_finite", $max_finite);
mk_constant("max_integer", $max_integer);

#
# Subnormals.
#

my $have_subnormal;
{
	my $testval = $min_finite * 1.5;
	$have_subnormal = $testval == $min_finite ||
				$testval == ($min_finite + $min_finite);
}

mk_constant("have_subnormal", $have_subnormal);

my $min_normal_exp = $have_subnormal ?
			$min_finite_exp + $significand_bits :
			$min_finite_exp;
my $min_normal = $have_subnormal ?
			mult_pow2($min_finite, $significand_bits) :
			$min_finite;

mk_constant("min_normal_exp", $min_normal_exp);
mk_constant("min_normal", $min_normal);

#
# Feature tests.
#

my $have_signed_zero = sprintf("%e", -0.0) =~ /\A-/;
mk_constant("have_signed_zero", $have_signed_zero);
my($pos_zero, $neg_zero);
if($have_signed_zero) {
	mk_constant("pos_zero", $pos_zero = +0.0);
	mk_constant("neg_zero", $neg_zero = -0.0);
}

my($have_infinite, $pos_infinity, $neg_infinity);
{
	my $testval = $max_finite * $max_finite;
	$have_infinite = $testval == $testval && $testval != $max_finite;
	mk_constant("have_infinite", $have_infinite);
	if($have_infinite) {
		mk_constant("pos_infinity", $pos_infinity = $testval);
		mk_constant("neg_infinity", $neg_infinity = -$testval);
	}
}

my($have_nan, $nan);
foreach my $nan_formula (
		'$have_infinite && $pos_infinity/$pos_infinity',
		'log(-1.0)',
		'0.0/0.0',
		'"nan"') {
	my $maybe_nan =
		eval 'local $SIG{__DIE__}; local $SIG{__WARN__} = sub { }; '.
		     $nan_formula;
	if(do { local $SIG{__WARN__} = sub { }; $maybe_nan != $maybe_nan }) {
		$have_nan = 1;
		$nan = $maybe_nan;
		mk_constant("nan", $nan);
		last;
	}
}
mk_constant("have_nan", $have_nan);

# The rest of the code is parsed after the constants have been calculated
# and installed, so that it can benefit from their constancy.
eval do { local $/; <DATA>; } or die $@;
__DATA__
local $SIG{__DIE__};

=head1 FUNCTIONS

Each "float_" function takes a floating point argument to operate on.
The argument must be a native floating point value, or a native
integer (which will be silently converted to floating point).  Giving a
non-numeric argument will cause mayhem.  See L<Params::Classify/is_number>
for a way to check for numericness.

=head2 Classification

Each "float_is_" function returns a simple boolean result.

=over

=item float_class(VALUE)

Determines which of the five classes described above VALUE falls
into. Returns "NORMAL", "SUBNORMAL", "ZERO", "INFINITE", or "NAN"
accordingly.

=cut

sub float_class($) {
	my($val) = @_;
	return "ZERO" if $val == 0.0;
	return "NAN" if $val != $val;
	$val = -$val if $val < 0;
	return "INFINITE" if have_infinite && $val == $pos_infinity;
	return have_subnormal && $val < min_normal ? "SUBNORMAL" : "NORMAL";
}

=item float_is_normal(VALUE)

Returns true iff VALUE is a normalised floating point value.

=cut

sub float_is_normal($) { float_class($_[0]) eq "NORMAL" }

=item float_is_subnormal(VALUE)

Returns true iff VALUE is a subnormal floating point value.

=cut

sub float_is_subnormal($) { float_class($_[0]) eq "SUBNORMAL" }

=item float_is_nzfinite(VALUE)

Returns true iff VALUE is a non-zero finite value (either normal or
subnormal; not zero, infinite, or NaN).

=cut

sub float_is_infinite($);

sub float_is_nzfinite($) {
	my($val) = @_;
	return $val != 0.0 && $val == $val && !float_is_infinite($val);
}

=item float_is_zero(VALUE)

Returns true iff VALUE is a zero.  If zeroes are signed then both signs
qualify.

=cut

sub float_is_zero($) {
	my($val) = @_;
	return $val == 0.0;
}

=item float_is_finite(VALUE)

Returns true iff VALUE is a finite value (either normal, subnormal,
or zero; not infinite or NaN).

=cut

sub float_is_finite($) {
	my($val) = @_;
	return $val == $val && !float_is_infinite($val);
}

=item float_is_infinite(VALUE)

Returns true iff VALUE is an infinity (either positive infinity or
negative infinity).

=cut

sub float_is_infinite($) {
	return undef unless have_infinite;
	my($val) = @_;
	return $val == $pos_infinity || $val == $neg_infinity;
}

=item float_is_nan(VALUE)

Returns true iff VALUE is a NaN.

=cut

sub float_is_nan($) {
	my($val) = @_;
	return $val != $val;
}

=back

=head2 Examination

=over

=item float_sign(VALUE)

Returns "+" or "-" to indicate the sign of VALUE.  If zero is unsigned
then it is treated as positive.  C<die>s if VALUE is a NaN.

=cut

sub float_sign($) {
	my($val) = @_;
	croak "can't get sign of a NaN" if $val != $val;
	return have_signed_zero && $val == 0.0 ?
		sprintf("%e", $val) =~ /\A-/ ? "-" : "+" :
		$val >= 0.0 ? "+" : "-";
}

=item float_parts(VALUE)

Divides up a non-zero finite floating point value into sign, exponent,
and significand, returning these as a three-element list in that order.
The significand is returned as a floating point value, in the range
[1, 2) for normalised values, and in the range (0, 1) for subnormals.
C<die>s if VALUE is not finite and non-zero.

=cut

sub float_parts($) {
	my($val) = @_;
	croak "$val is not non-zero finite" unless float_is_nzfinite($val);
	my $sign = "+";
	if($val < 0.0) {
		$sign = "-";
		$val = -$val;
	}
	if(have_subnormal && $val < min_normal) {
		return ($sign, min_normal_exp,
			mult_pow2($val, -(min_normal_exp)));
	}
	my $exp = 0;
	if($val < 1.0) {
		for(my $i = @powhalf; $i--; ) {
			$exp <<= 1;
			if($val < $powhalf[$i]) {
				$exp |= 1;
				$val = mult_pow2($val, 1 << $i);
			}
		}
		$val *= 2.0;
		$exp = -1-$exp;
	} elsif($val >= 2.0) {
		for(my $i = @powtwo; $i--; ) {
			$exp <<= 1;
			if($val >= $powtwo[$i]) {
				$exp |= 1;
				$val = mult_pow2($val, -(1 << $i));
			}
		}
	}
	return ($sign, $exp, $val);
}

=item float_hex(VALUE[, OPTIONS])

Encodes the exact value of VALUE as a hexadecimal fraction, returning
the fraction as a string.  Specifically, for finite values the output is
of the form "I<s>B<0x>I<m>B<.>I<mmmmm>B<p>I<eee>", where "I<s>" is the
sign, "I<m>B<.>I<mmmm>" is the significand in hexadecimal, and "I<eee>"
is the exponent in decimal with a sign.

The details of the output format are very configurable.  If OPTIONS
is supplied, it must be a reference to a hash, in which these keys may
be present:

=over

=item B<exp_digits>

The number of digits of exponent to show, unless this is modified by
B<exp_digits_range_mod> or more are required to show the exponent exactly.
(The exponent is always shown in full.)  Default 0, so the minimum
possible number of digits is used.

=item B<exp_digits_range_mod>

Modifies the number of exponent digits to show, based on the number of
digits required to show the full range of exponents for normalised and
subnormal values.  If "B<IGNORE>" then nothing is done.  If "B<ATLEAST>"
then at least this many digits are shown.  Default "B<IGNORE>".

=item B<exp_neg_sign>

The string that is prepended to a negative exponent.  Default "B<->".

=item B<exp_pos_sign>

The string that is prepended to a non-negative exponent.  Default "B<+>".
Make it the empty string to suppress the positive sign.

=item B<frac_digits>

The number of fractional digits to show, unless this is modified by
B<frac_digits_bits_mod> or B<frac_digits_value_mod>.  Default 0, but by
default this gets modified.

=item B<frac_digits_bits_mod>

Modifies the number of fractional digits to show, based on the length of
the significand.  There is a certain number of digits that is the minimum
required to explicitly state every bit that is stored, and the number
of digits to show might get set to that number depending on this option.
If "B<IGNORE>" then nothing is done.  If "B<ATLEAST>" then at least this
many digits are shown.  If "B<ATMOST>" then at most this many digits
are shown.  If "B<EXACTLY>" then exactly this many digits are shown.
Default "B<ATLEAST>".

=item B<frac_digits_value_mod>

Modifies the number of fractional digits to show, based on the number
of digits required to show the actual value exactly.  Works the same
way as B<frac_digits_bits_mod>.  Default "B<ATLEAST>".

=item B<infinite_string>

The string that is returned for an infinite magnitude.  Default "B<inf>".

=item B<nan_string>

The string that is returned for a NaN value.  Default "B<nan>".

=item B<neg_sign>

The string that is prepended to a negative value (including negative
zero).  Default "B<->".

=item B<pos_sign>

The string that is prepended to a positive value (including positive or
unsigned zero).  Default "B<+>".  Make it the empty string to suppress
the positive sign.

=item B<subnormal_strategy>

The manner in which subnormal values are displayed.  If "B<SUBNORMAL>",
they are shown with the minimum exponent for normalised values and
a significand in the range (0, 1).  This matches how they are stored
internally.  If "B<NORMAL>", they are shown with a significand in the
range [1, 2) and a lower exponent, as if they were normalised.  This gives
a consistent appearance for magnitudes regardless of normalisation.
Default "B<SUBNORMAL>".

=item B<zero_strategy>

The manner in which zero values are displayed.  If "B<STRING=>I<str>", the
string I<str> is used.  If "B<SUBNORMAL>", it is shown with significand
zero and the minimum normalised exponent.  If "B<EXPONENT=>I<exp>", it is
shown with significand zero and exponent I<exp>.  Default "B<STRING=0.0>".

=back

=cut

my %float_hex_defaults = (
	infinite_string => "inf",
	nan_string => "nan",
	exp_neg_sign => "-",
	exp_pos_sign => "+",
	pos_sign => "+",
	neg_sign => "-",
	subnormal_strategy => "SUBNORMAL",
	zero_strategy => "STRING=0.0",
	frac_digits => 0,
	frac_digits_bits_mod => "ATLEAST",
	frac_digits_value_mod => "ATLEAST",
	exp_digits => 0,
	exp_digits_range_mod => "IGNORE",
);

sub float_hex_option($$) {
	my($options, $name) = @_;
	my $val = defined($options) ? $options->{$name} : undef;
	return defined($val) ? $val : $float_hex_defaults{$name};
}

use constant exp_digits_range => do {
	my $minexp = min_normal_exp - significand_bits;
	my $maxexp = max_finite_exp + 1;
	my $len_minexp = length(-$minexp);
	my $len_maxexp = length($maxexp);
	$len_minexp > $len_maxexp ? $len_minexp : $len_maxexp;
};
use constant frac_digits_bits => (significand_bits + 3) >> 2;
use constant frac_sections => do { use integer; (frac_digits_bits + 6) / 7; };

sub float_hex($;$) {
	my($val, $options) = @_;
	return float_hex_option($options, "nan_string") if $val != $val;
	if(have_infinite) {
		my $inf_sign;
		if($val == $pos_infinity) {
			$inf_sign = float_hex_option($options, "pos_sign");
			EMIT_INFINITY:
			return $inf_sign.
				float_hex_option($options, "infinite_string");
		} elsif($val == $neg_infinity) {
			$inf_sign = float_hex_option($options, "neg_sign");
			goto EMIT_INFINITY;
		}
	}
	my($sign, $exp, $sgnf);
	if($val == 0.0) {
		$sign = float_sign($val);
		my $strat = float_hex_option($options, "zero_strategy");
		if($strat =~ /\ASTRING=(.*)\z/s) {
			my $string = $1;
			return float_hex_option($options,
				    $sign eq "-" ? "neg_sign" : "pos_sign").
				$string;
		} elsif($strat eq "SUBNORMAL") {
			$exp = min_normal_exp;
		} elsif($strat =~ /\AEXPONENT=([-+]?\d+)\z/) {
			$exp = $1;
		} else {
			croak "unrecognised zero strategy `$strat'";
		}
		$sgnf = 0.0;
	} else {
		($sign, $exp, $sgnf) = float_parts($val);
	}
	my $digits = int($sgnf);
	if($digits eq "0" && $sgnf != 0.0) {
		my $strat = float_hex_option($options, "subnormal_strategy");
		if($strat eq "NORMAL") {
			my $add_exp;
			(undef, $add_exp, $sgnf) = float_parts($sgnf);
			$exp += $add_exp;
			$digits = "1";
		} elsif($strat eq "SUBNORMAL") {
			# do nothing extra
		} else {
			croak "unrecognised subnormal strategy `$strat'";
		}
	}
	$sgnf -= $digits;
	for(my $i = frac_sections; $i--; ) {
		$sgnf *= 268435456.0;
		my $section = int($sgnf);
		$digits .= sprintf("%07x", $section);
		$sgnf -= $section;
	}
	$digits =~ s/(.)0+\z/$1/;
	my $ndigits = 1 + float_hex_option($options, "frac_digits");
	croak "negative number of digits requested" if $ndigits <= 0;
	my $mindigits = 1;
	my $maxdigits = $ndigits + frac_digits_bits;
	foreach my $constraint (["frac_digits_bits_mod", 1+frac_digits_bits],
				["frac_digits_value_mod", length($digits)]) {
		my($optname, $number) = @$constraint;
		my $mod = float_hex_option($options, $optname);
		if($mod =~ /\A(?:ATLEAST|EXACTLY)\z/) {
			$mindigits = $number if $mindigits < $number;
		}
		if($mod =~ /\A(?:ATMOST|EXACTLY)\z/) {
			$maxdigits = $number if $maxdigits > $number;
		}
		croak "unrecognised length modification setting `$mod'"
			unless $mod =~ /\A(?:AT(?:MO|LEA)ST|EXACTLY|IGNORE)\z/;
	}
	croak "incompatible length constraints" if $maxdigits < $mindigits;
	$ndigits = $ndigits < $mindigits ? $mindigits :
			$ndigits > $maxdigits ? $maxdigits : $ndigits;
	if($ndigits > length($digits)) {
		$digits .= "0" x ($ndigits - length($digits));
	} elsif($ndigits < length($digits)) {
		my $chopped = substr($digits, $ndigits, length($digits), "");
		if($chopped =~ /\A[89abcdef]/ &&
				!($chopped =~ /\A80*\z/ &&
				  $digits =~ /[02468ace]\z/)) {
			for(my $i = length($digits) - 1; ; ) {
				my $d = substr($digits, $i, 1);
				$d =~ tr/0-9a-f/1-9a-f0/;
				substr($digits, $i, 1, $d);
				last unless $d eq "0";
			}
			if($digits =~ /\A2/) {
				$exp++;
				substr($digits, 0, 1, "1");
			}
		}
	}
	my $nexpdigits = float_hex_option($options, "exp_digits");
	my $mod = float_hex_option($options, "exp_digits_range_mod");
	if($mod eq "ATLEAST") {
		$nexpdigits = exp_digits_range
			if $nexpdigits < exp_digits_range;
	} elsif($mod ne "IGNORE") {
		croak "unrecognised exponent length ".
			"modification setting `$mod'";
	}
	$digits =~ s/\A(.)(.)/$1.$2/;
	return sprintf("%s0x%sp%s%0*d",
		float_hex_option($options,
			$sign eq "-" ? "neg_sign" : "pos_sign"),
		$digits,
		float_hex_option($options,
			$exp < 0 ? "exp_neg_sign" : "exp_pos_sign"),
		$nexpdigits, abs($exp));
}

=back

=head2 Manipulation

=over

=item pow2(EXP)

EXP must be an integer.  Returns the value two the the power EXP.
C<die>s if that value cannot be represented exactly as a floating
point value.  The return value may be either normalised or subnormal.

=item mult_pow2(VALUE, EXP)

EXP must be an integer, and VALUE a floating point value.  Multiplies
VALUE by two to the power EXP.  This gives exact results, except in
cases of underflow and overflow.  The range of EXP is not constrained.
All normal floating point multiplication behaviour applies.

=item copysign(VALUE, SIGN_FROM)

VALUE and SIGN_FROM must both be floating point values.  Returns a
floating point value with the magnitude of VALUE and the sign of
SIGN_FROM.  If SIGN_FROM is an unsigned zero then it is treated as
positive.  If VALUE is an unsigned zero then it is returned unchanged.
If VALUE is a NaN then it is returned unchanged.  If SIGN_FROM is a NaN
then the function C<die>s.

=cut

sub copysign($$) {
	my($val, $signfrom) = @_;
	return $val if float_is_nan($val);
	$val = -$val if float_sign($val) ne float_sign($signfrom);
	return $val;
}

=item nextafter(VALUE, DIRECTION)

Returns the next representable floating point value adjacent to VALUE
in the direction of DIRECTION.  Returns a NaN if either argument
is a NaN, and returns VALUE unchanged if it is numerically equal
to DIRECTION.  Infinite values are regarded as being adjacent to the
largest representable finite values.  Zero counts as one value, even if
it is signed, and it is adjacent to the positive and negative smallest
representable finite values.  If a zero is returned and zeroes are signed
then it has the same sign as VALUE.

=cut

sub nextafter($$) {
	my($val, $dir) = @_;
	return $val if $val != $val;
	return $dir if $dir != $dir;
	return $_[0] if $val == $dir;
	return $dir > 0.0 ? min_finite : -(min_finite) if $val == 0.0;
	return copysign(max_finite, $val) if float_is_infinite($val);
	my($sign, $exp, $significand) = float_parts($val);
	if(float_sign($dir) eq $sign && abs($dir) > abs($val)) {
		$significand += significand_step;
		if($significand == 2.0) {
			return $dir if $exp == max_finite_exp;
			$significand = 1.0;
			$exp++;
		}
	} else {
		if($significand == 1.0 && $exp != min_normal_exp) {
			$significand = 2.0;
			$exp--;
		}
		$significand -= significand_step;
	}
	return copysign(mult_pow2($significand, $exp), $val);
}

=back

=head1 BUGS

Perl (as of version 5.8.7) doesn't reliably maintain the sign of a zero.
The functions in this module all handle the sign of a zero correctly if it
is present, but they can't rescue the sign if it has already been lost.
Avoid relying on correct signed-zero handling, even if you know your
hardware handles it correctly.

NaN handling is generally not well defined in Perl.  Arithmetic with
a mathematically undefined result may either C<die> or generate a NaN.
Avoid relying on any particular behaviour for such operations, even if
your hardware's behaviour is known.

=head1 AUTHOR

Andrew Main (Zefram) <zefram@fysh.org>

=head1 COPYRIGHT

Copyright (C) 2006 Andrew Main (Zefram) <zefram@fysh.org>

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
