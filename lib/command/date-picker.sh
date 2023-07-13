#!/bin/bash
#
# date-picker
#
umask 022

PROGNAME=${0##*/}
BASEDIR=$(cd $(dirname $0); pwd)
PREFIX=$(cd $(dirname $BASEDIR)/..; pwd)
SELF="$(cd $(dirname $0); pwd)/$PROGNAME"
VERSION='0.1'

COMMONFUNCS=${MK_HOME}/init.sh

if test -f $COMMONFUNCS
then
	. $COMMONFUNCS
else
	echo "ERROR: Could not load $COMMONFUNCS"  >&2
	exit 1
fi

usage ()
{
	pod2text "$self" | more
	exit 1
}

while [[ $# -gt 0 ]]
do
	case "$1" in
		-o|--output)
				[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
				mk_set logfile "$2"
				shift
				;;
		-s|--startdate)
				[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
				mk_set startdate "$2"
				shift
				;;
		-e|--enddate)
				[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
				mk_set enddate "$2"
				shift
				;;
		-l|--list)
				mk_set DO_LIST "| xargs"
				;;
		-X|--debug)
				mk_set MK_DEBUG 1
				;;
		-v|--verbose)
				mk_set MK_VERBOSE 1
				;;
		-h|--help)
				mk_usage
				;;
		--man)
				mk_man
				;;
		-V|--version)
				version
				;;
		--defaults)
				mk_set print_defaults 1
				;;
		-*)
				mk_error "Invalid option '$1'"
				mk_help
				;;
		*)
				break
				;;
		esac
		shift
done

if [[ -n "${logfile}" ]]
then
	exec 4>${logfile}
	MK_LOG_FD=4
fi

mk_date_to_julian $startdate
s="$result"

mk_date_to_julian $enddate
e="$result"

if [ "$s" -eq "$e" ]
then
	mk_julian_to_date $s
	mk_msg "$result"
	exit 0
fi
#[ "$s" -eq "$e" ] && s=$(($s-1))
[ "$s" -le "$e" ] \
	|| mk_fail "ENDDATE (${enddate}) is less than STARTDATE (${startdate})"

mk_julian_to_date $s
_startdate="$result"
mk_julian_to_date $e
_enddate="$result"
TZ=GMT

days=$(( ($e - $s) + 1 ))
mk_msg_debug "DAYS = $days"
_dates=
x=$s
while [ "$x" -le "$e" ]
do
	mk_julian_to_date "$x"
	mk_append_list _dates "$result"
	x=$(( $x + 1 ))
done

mk_unquote_list $_dates
if [ -n "$DO_LIST" ]
then
	mk_msg "$@"
else	
	for _d
	do
		mk_msg "$_d"
	done 
fi
exit 0 

: <<=cut

=pod

=head1 NAME

date-picker: Generate date ranges

=head1 USAGE

date-picker [-h|--help] [ARG...]

=over

=item -h, --help

Help information

=back

=over

=item --man

Print man page

=back

=over

=item -s, --startdate

The startdate for the search (default: today)
Dates are in the form of YYYYMMDD

(Also follows the LT_STARTDATE environment variable)

=back

=over

=item -e, --enddate

The enddate for the search (default: today)
Dates are in the form of YYYYMMDD

=back

=over

=item -l, --list

Output dates on a single line

=back

=over

=item -o outfile, --outfile <outfile>

Log the output to <outfile>

=back

=over

=item -X, --debug

debug logging

=back

=over

=item -v, --verbose

verbose logging

=back

=over

=item -V, --version

script version

=back

=head1 AUTHOR

Jason Prondak, E<lt>jprondak.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
