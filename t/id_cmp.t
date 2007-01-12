use Test::More tests => 82;

BEGIN { use_ok "Data::Float", qw(
	have_infinite have_signed_zero have_nan float_id_cmp
); }

my @values = (
	sub { have_nan ? &{"Data::Float::nan"} : undef },
	sub { have_infinite ? &{"Data::Float::neg_infinity"} : undef },
	-1000.0,
	-0.125,
	sub { have_signed_zero ? &{"Data::Float::neg_zero"} : undef },
	+0.0,
	+0.125,
	+1000.0,
	sub { have_infinite ? &{"Data::Float::pos_infinity"} : undef },
);

foreach(@values) {
	$_ = $_->() if ref($_) eq "CODE";
}

for(my $ia = @values; $ia--; ) {
	for(my $ib = @values; $ib--; ) {
		SKIP: {
			my $a = $values[$ia];
			my $b = $values[$ib];
			skip "special value not available", 1
				unless defined($a) && defined($b);
			my $expect = ($ia <=> $ib);
			my $actual = float_id_cmp($a, $b);
			ok $expect < 0 && $actual < 0 ||
				$expect == 0 && $actual == 0 ||
				$expect > 0 && $actual > 0;
		}
	}
}
