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

	use Data::Float qw(float_sign signbit float_parts);

	$sign = float_sign($value);
	$sign_bit = signbit($value);
	($sign, $exponent, $significand) = float_parts($value);

	use Data::Float qw(float_hex hex_float);

	print float_hex($value);
	$value = hex_float($string);

	use Data::Float qw(float_id_cmp);

	@sorted_floats = sort { float_id_cmp($a, $b) } @floats;

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

=head2 Classification

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

Perl has only (at most) one NaN value, even if the underlying system
supports different NaNs.  (IEEE 754 arithmetic has NaNs which carry a
quiet/signal bit, a sign bit (yes, a sign on a not-number), and many
bits of implementation-defined data.)

=back

=head2 Mixing floating point and integer values

Perl does not draw a strong type distinction between native integer
(see L<Data::Integer>) and native floating point values.  Both types
of value can be stored in the numeric part of a plain (string) scalar.
No distinction is made between the integer representation and the floating
point representation where they encode identical values.  Thus, for
floating point arithmetic, native integer values that can be represented
exactly in floating point may be freely used as floating point values.

Native integer arithmetic has exactly one zero value, which has no sign.
If the floating point type does not have signed zeroes then the floating
point and integer zeroes are exactly equivalent.  If the floating point
type does have signed zeroes then the integer zero can still be used in
floating point arithmetic, and it behaves as an unsigned floating point
zero.  On such systems there are therefore three types of zero available.
There is a bug in Perl which sometimes causes floating point zeroes to
change into integer zeroes; see L</BUGS> for details.

Where a native integer value is used that is too large to exactly
represent in floating point, it will be rounded as necessary to a
floating point value.  This rounding will occur whenever an operation
has to be performed in floating point because the result could not be
exactly represented as an integer.  This may be confusing to functions
that expect a floating point argument.

Similarly, some operations on floating point numbers will actually be
performed in integer arithmetic, and may result in values that cannot
be exactly represented in floating point.  This happens whenever the
arguments have integer values that fit into the native integer type and
the mathematical result can be exactly represented as a native integer.
This may be confusing in cases where floating point semantics are
expected.

See L<perlnumber(1)> for discussion of Perl's numeric semantics.

=cut

package Data::Float;

use warnings;
use strict;

use Carp qw(croak);

our $VERSION = "0.005";

use base "Exporter";
our @EXPORT_OK = qw(
	float_class float_is_normal float_is_subnormal float_is_nzfinite
	float_is_zero float_is_finite float_is_infinite float_is_nan
	float_sign signbit float_parts
	float_hex hex_float
	float_id_cmp
	pow2 mult_pow2 copysign nextafter
);
# constant functions get added to @EXPORT_OK later

=head1 CONSTANTS

=head2 Features

=over

=item have_signed_zero

Boolean indicating whether floating point zeroes carry a sign.  If yes,
then there are two floating point zero values: +0.0 and -0.0.  (Perl
scalars can nevertheless also hold an integer zero, which is unsigned.)
If no, then there is only one zero value, which is unsigned.

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
point values.  The significand also has an implicit integer bit, not
counted in this constant; the integer bit is always 1 for normalised
values and always 0 for subnormal values.

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

The maximum integral value for which all integers from zero to that
value inclusive are representable.  Equivalently: the minimum positive
integral value N for which the value N+1 is not representable.  This is
2^(significand_bits+1).  The name is somewhat misleading.

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

If Perl is at risk of transforming floating point zeroes into integer
zeroes (see L</BUGS>), then this is actually a non-constant function
that always returns a fresh floating point zero.  Thus the return value
is always a true floating point zero, regardless of what happened to
zeroes previously returned.

=item neg_zero

The negative zero value.  (Exists only if zeroes are signed, as indicated
by the C<have_signed_zero> constant.)

If Perl is at risk of transforming floating point zeroes into integer
zeroes (see L</BUGS>), then this is actually a non-constant function
that always returns a fresh floating point zero.  Thus the return value
is always a true floating point zero, regardless of what happened to
zeroes previously returned.

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

my $max_integer = pow2($significand_bits + 1);

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
	$pos_zero = +0.0;
	$neg_zero = -0.0;
	my $tzero = -0.0;
	{ no warnings "void"; $tzero == $tzero; }
	if(sprintf("%e", - -$tzero) =~ /\A-/) {
		mk_constant("pos_zero", $pos_zero);
		mk_constant("neg_zero", $neg_zero);
	} else {
		# Zeroes lose their signedness upon arithmetic operations.
		# Therefore make the pos_zero and neg_zero functions
		# return fresh zeroes to avoid trouble.
		*pos_zero = sub () { my $ret = $pos_zero };
		*neg_zero = sub () { my $ret = $neg_zero };
		push @EXPORT_OK, "pos_zero", "neg_zero";
	}
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

Each "float_" function takes a floating point argument to operate on.  The
argument must be a native floating point value, or a native integer with
a value that can be represented in floating point.  Giving a non-numeric
argument will cause mayhem.  See L<Params::Classify/is_number> for a way
to check for numericness.  Only the numeric value of the scalar is used;
the string value is completely ignored, so dualvars are not a problem.

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

Returns true iff VALUE is a zero.  If zeroes are signed then the sign
is irrelevant.

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

Returns "B<+>" or "B<->" to indicate the sign of VALUE.  An unsigned
zero returns the sign "B<+>".  C<die>s if VALUE is a NaN.

=cut

sub signbit($);

sub float_sign($) {
	my($val) = @_;
	croak "can't get sign of a NaN" if $val != $val;
	return signbit($val) ? "-" : "+";
}

=item signbit(VALUE)

VALUE must be a floating point value.  Returns the sign bit of VALUE:
0 if VALUE is positive or a positive or unsigned zero, or 1 if VALUE is
negative or a negative zero.  Returns an unpredictable value if VALUE
is a NaN.

This is an IEEE 754 standard function.

=cut

sub signbit($) {
	my($val) = @_;
	return (have_signed_zero && $val == 0.0 ?
		sprintf("%+.f", $val) eq "-0" : $val < 0.0) ? 1 : 0;
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

=back

=head2 String conversion

=over

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

The manner in which zero values are displayed.  If "B<STRING=>I<str>",
the string I<str> is used, preceded by a sign.  If "B<SUBNORMAL>",
it is shown with significand zero and the minimum normalised exponent.
If "B<EXPONENT=>I<exp>", it is shown with significand zero and exponent
I<exp>.  Default "B<STRING=0.0>".  An unsigned zero is treated as having
a positive sign.

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

=item hex_float(STRING)

Generates and returns a floating point value from a string
encoding it in hexadecimal.  The standard input form is
"[I<s>]B<0x>I<m>[B<.>I<mmmmm>][B<p>I<eee>]", where "I<s>" is the sign,
"I<m>[B<.>I<mmmm>]" is a (fractional) hexadecimal number, and "I<eee>"
an optionally-signed exponent in decimal.  If present, the exponent
identifies a power of two (not sixteen) by which the given fraction will
be multiplied.

If the value given in the string cannot be exactly represented in the
floating point type because it has too many fraction bits, the nearest
representable value is returned, with ties broken in favour of the value
with a zero low-order bit.  If the value given is too large to exactly
represent then an infinity is returned, or the largest finite value if
there are no infinities.

Additional input formats are accepted for special values.
"[I<s>]B<inf>" returns an infinity, or C<die>s if there are no infinities.
"[I<s>]B<nan>" returns a NaN, or C<die>s if there are no NaNs available.
"I<s>B<0>[B<.0>]", with additional consecutive zero digits allowed before
or after the point, returns a zero.

All input formats are understood case insensitively.  The function
correctly interprets all possible outputs from C<float_hex> with default
settings.

=cut

sub hex_float($) {
	my($str) = @_;
	if($str =~ /\A([-+]?)0x([0-9a-f]+)(?:\.([0-9a-f]+)+)?
		    (?:p([-+]?\d+))?\z/xi) {
		my($sign, $digits, $frac_digits, $in_exp) = ($1, $2, $3, $4);
		my $value;
		$frac_digits = "" unless defined $frac_digits;
		$in_exp = "0" unless defined $in_exp;
		$digits .= $frac_digits;
		$digits =~ s/\A0+//;
		if($digits eq "") {
			$value = 0.0;
			goto GOT_MAG;
		}
		my $digit_exp = (length($digits) - length($frac_digits)) * 4;
		my @limbs;
		push @limbs, hex($1) while $digits =~ /(.{7})/sgc;
		push @limbs, hex(substr($1."000000", 0, 7))
			if $digits =~ /(.+)/sg;
		my $skip_bits = $limbs[0] < 0x4000000 ?
			$limbs[0] < 0x2000000 ? 3 : 2 :
			$limbs[0] < 0x8000000 ? 1 : 0;
		my $val_exp = $digit_exp - $skip_bits - 1 + $in_exp;
		my $sig_bits;
		if($val_exp > max_finite_exp) {
			$value = have_infinite ? Data::Float::pos_infinity :
						 max_finite;
			goto GOT_MAG;
		} elsif($val_exp < min_finite_exp-1) {
			$value = 0.0;
			goto GOT_MAG;
		} elsif($val_exp < min_normal_exp) {
			$sig_bits = $val_exp - (min_finite_exp-1);
		} else {
			$sig_bits = significand_bits+1;
		}
		my $gbit_lpos = do { use integer; ($skip_bits+$sig_bits)/28 };
		if(@limbs > $gbit_lpos) {
			my $gbit_bpos = 27 - ($skip_bits + $sig_bits) % 28;
			my $sbit = 0;
			while(@limbs > $gbit_lpos+1) {
				$sbit = 1 if pop(@limbs) != 0;
			}
			my $gbit_mask = 1 << $gbit_bpos;
			my $sbit_mask = $gbit_mask - 1;
			if($limbs[$gbit_lpos] & $sbit_mask) {
				$sbit = 1;
				$limbs[$gbit_lpos] &= ~$sbit_mask;
			}
			if($limbs[$gbit_lpos] & $gbit_mask) {
				unless($sbit) {
					if($gbit_bpos == 27 &&
					   $gbit_lpos != 0) {
						$sbit = $limbs[$gbit_lpos - 1]
							& 1;
					} else {
						$sbit = $limbs[$gbit_lpos] &
							($gbit_mask << 1);
					}
				}
				if($sbit) {
					$limbs[$gbit_lpos] += $gbit_mask;
				} else {
					$limbs[$gbit_lpos] -= $gbit_mask;
				}
			}
		}
		$value = 0.0;
		for(my $i = @limbs; $i--; ) {
			$value += mult_pow2($limbs[$i], -28*($i+1));
		}
		$value = mult_pow2($value, $in_exp + $digit_exp);
		GOT_MAG:
		return $sign eq "-" ? -$value : $value;
	} elsif($str =~ /\A([-+]?)0+(?:\.0+)?\z/) {
		return my $zero = $1 eq "-" ? -0.0 : +0.0;
	} elsif($str =~ /\A([-+]?)inf\z/i) {
		croak "infinite values not available" unless have_infinite;
		return $1 eq "-" ? Data::Float::neg_infinity :
				   Data::Float::pos_infinity;
	} elsif($str =~ /\A([-+]?)nan\z/si) {
		croak "Nan value not available" unless have_nan;
		return Data::Float::nan;
	} else {
		croak "bad syntax for hexadecimal floating point value";
	}
}

=back

=head2 Comparison

=over

=item float_id_cmp(A, B)

This is a comparison function supplying a total ordering of floating
point values.  A and B must both be floating point values.  Returns -1,
0, or +1, indicating whether A is to be sorted before, the same as,
or after B.

The ordering is of the identities of floating point values, not their
numerical values.  If zeroes are signed, then the two types are considered
to be distinct.  NaNs compare equal to each other, but different from
all numeric values.  The exact ordering provided is mostly numerical
order: NaNs come first, followed by negative infinity, then negative
finite values, then negative zero, then positive (or unsigned) zero,
then positive finite values, then positive infinity.

In addition to sorting, this function can be useful to check for a zero
of a particular sign.

This function provides essentially the same capability as the IEEE 754r
function totalorder().  The interface differs, in that totalorder()
provides a <= predicate whereas float_id_cmp() provides a Perl-style <=>
three-way comparison.  They also differ in that totalorder() distinguishes
different kinds of NaN, whereas float_id_cmp() (like the rest of Perl)
perceives only one NaN.

=cut

sub float_id_cmp($$) {
	my($a, $b) = @_;
	if(float_is_nan($a)) {
		return float_is_nan($b) ? 0 : -1;
	} elsif(float_is_nan($b)) {
		return +1;
	} elsif(float_is_zero($a) && float_is_zero($b)) {
		return signbit($b) - signbit($a);
	} else {
		return $a <=> $b;
	}
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

This is an IEEE 754 standard function.

=cut

sub copysign($$) {
	my($val, $signfrom) = @_;
	return $val if float_is_nan($val);
	$val = -$val if signbit($val) != signbit($signfrom);
	return $val;
}

=item nextafter(VALUE, DIRECTION)

VALUE and DIRECTION must both be floating point values.  Returns the next
representable floating point value adjacent to VALUE in the direction of
DIRECTION.  Returns a NaN if either argument is a NaN, and returns VALUE
unchanged if it is numerically equal to DIRECTION.  Infinite values are
regarded as being adjacent to the largest representable finite values.
Zero counts as one value, even if it is signed, and it is adjacent to
the positive and negative smallest representable finite values.  If a
zero is returned and zeroes are signed then it has the same sign as VALUE.

This is an IEEE 754 standard function.

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

As of Perl 5.8.7 floating point zeroes will be partially transformed into
integer zeroes if used in almost any arithmetic, including numerical
comparisons.  Such a transformed zero appears as a floating point zero
(with its original sign) for some purposes, but behaves as an integer
zero for other purposes.  Where this happens to a positive zero the
result is indistinguishable from a true integer zero.  Where it happens
to a negative zero the result is a fourth type of zero, the existence of
which is a bug in Perl.  This fourth type of zero will give confusing
results, and in particular will elicit inconsistent behaviour from the
functions in this module.

Because of this transforming behaviour, it is best to avoid relying on
the sign of zeroes.  If you require signed-zero semantics then take
special care to maintain signedness.  Avoid using a zero directly
in arithmetic and handle it as a special case.  Any flavour of zero
can be accurately copied from one scalar to another without affecting
the original.  The functions in this module all avoid modifying their
arguments, and where they are meant to return signed zeroes they always
return a pristine one.

As of Perl 5.8.7 stringification of a floating point zero does not
preserve its signedness.  The number-to-string-to-number round trip
turns a positive floating point zero into an integer zero, but accurately
maintains negative and integer zeroes.  If a negative zero gets partially
transformed into an integer zero, as described above, the stringification
that it gets is based on its state at the first occasion on which the
scalar was stringified.

NaN handling is generally not well defined in Perl.  Arithmetic with
a mathematically undefined result may either C<die> or generate a NaN.
Avoid relying on any particular behaviour for such operations, even if
your hardware's behaviour is known.

As of Perl 5.8.7 the B<%> operator truncates its arguments to integers, if
the divisor is within the range of the native integer type.  It therefore
operates correctly on non-integer values only when the divisor is
very large.

=head1 SEE ALSO

L<Data::Integer>,
L<Scalar::Number>,
L<perlnumber(1)>

=head1 AUTHOR

Andrew Main (Zefram) <zefram@fysh.org>

=head1 COPYRIGHT

Copyright (C) 2006, 2007 Andrew Main (Zefram) <zefram@fysh.org>

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
