#!/bin/bash
#
# find-latest-logs
#
umask 022

PROGNAME=${0##*/}
BASEDIR=$(cd $(dirname $0); pwd)
PREFIX=$(cd $(dirname $BASEDIR)/..; pwd)
SELF="$(cd $(dirname $0); pwd)/$PROGNAME"
REVISION='$Revision: 9058 $'
VERSION="0.1"

[ "$REVISION" = "$VERSION" ] && VERSION=
: ${VERSION:=1}

COMMONFUNCS=${MK_HOME}/init.sh

if test -f $COMMONFUNCS
then
	. $COMMONFUNCS
else
	echo "ERROR: Could not load $COMMONFUNCS"  >&2
	exit 1
fi

mk_msg_domain "$MK_COMMAND"

usage ()
{
	pod2text "$self" | more
	exit 1
}

_print_defaults ()
{

	for i in \
		prefix exec_prefix mandir libdir sbindir bindir datadir \
		sysconfdir llibdir lbindir lsbindir localstatedir \
		startdate enddate archivedir buckets \
		metadir logdir
	do
		mk_get "$i"
		mk_msg "$i = $result"
	done
	exit 0;
}

mk_set CMD list_buckets

while [[ $# -gt 0 ]]
do
	case "$1" in
		-o|--output)
                [ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
                mk_set logfile "$2"
                shift
                ;;
        -a|--archivedir)
                [ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
                mk_set archivedir "$2"
                shift
                ;;
		--recheck)
				mk_set recheck 1
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
		-n|--names)
				mk_set CMD list_bucket_names
				;;
		-l|--list)
				mk_set DO_LIST "| mk_unique_list"
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

mk_absolute_path "$metadir"
mk_set metadir "$result"

mk_get print_defaults
[ -n "$result" ] && _print_defaults
set -- $CMD $DO_LIST
eval "$@"

exit 0

: <<=cut

=pod

=head1 NAME

list-buckets: List the bucket names in the segway archive

=head1 USAGE

list-buckets [-h|--help] [ARG...]

=over

=item -h, --help

Help information

=back

=over

=item --man

Print man page

=back

=over

=item -n, --names

List just the names of the buckets

=back

=over

=item -l, --list

Return the results in a single line list

=back

=over

=item -a, --archivedir

The location for the archivedir
  Defaults to environment variable LT_ARCHIVEDIR, the /data01/SOC_LOG_ARCHIVE

=back

=over

=item -o outfile, --outfile <outfile>

Log the output to <outfile>

=back

=item -x

script debug. Same as set -x 

=back

=over

=item -D, --debug

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
