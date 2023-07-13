#!/usr/bin/perl


use Data::Dumper;
use Text::ParseWords;
my %words = ();
while (<>) {
	map { print "$_\n";$words{$_}++ }
#	grep {
#		m/\A(?:
#			\b((?:\d{1,3}\.){3}\d{1,3})\b
#			|
#			\w+-\w+-\w+
#		)\Z/sxc
#	 }
	grep { !/\d+-\d+-\d+/ }
	grep { defined }
	map { (split(/=/)) }
	parse_line(q{[\s,|:\[\]\(\)<>\+\/]+}, 0, $_);
}

END {
        print STDERR "$PROGNAME: " . scalar keys(%words) . " found\n";
        print map { "$_\n" } keys %words;
}

