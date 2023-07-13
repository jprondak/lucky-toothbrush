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
VERSION=$(echo $REVISION | sed -e 's/^\$Revision.* \([0-9]*\) .*/\1/')

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

while [[ $# -gt 0 ]]
do
	case "$1" in
		-c|--config)
				[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
				mk_safe_source "$2" \
					|| mk_fail "Failed to config '$2'"
				shift
				;;
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
		-a|--archivedir)
				[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
				mk_set archivedir "$2"
				shift
				;;
		-m|--metadir)
				[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
				mk_set metadir "$2"
				shift
				;;
		-b|--bucket)
				[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
				mk_append_list buckets `echo "$2" | mk_split ","`
				shift
				;;
		--recheck)
				mk_set recheck 1
				;;
		--verify)
				mk_set verify 1
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

mk_set retcode 0
mk_absolute_path "$metadir"
mk_set metadir "$result"
mk_absolute_path "$logdir"
mk_set logdir "$result"

mk_get print_defaults
[ -n "$result" ] && _print_defaults

mk_msg "START: `date`"
mk_msg "METADIR: ${metadir}"
mk_msg "ARCHIVEDIR: ${archivedir}"

mk_msg "STARTDATE: ${startdate}"
mk_msg "ENDDATE: ${enddate}"

if [ ! -d "${metadir}" ]
then
	mk_mkdir "${metadir}"
	mk_msg "Created ${metadir}"
fi

mk_set bucket_list "`list_bucket_names | mk_unique_list`"
[ -z "${buckets}" ] && mk_fail "No buckets to scan"

mk_unquote_list $buckets
buckets=
for _bucket
do
	mk_append_list buckets `echo "$_bucket" | mk_split ","`
done
mk_unquote_list $buckets
for _bucket
do
	_mk_contains "$_bucket" $bucket_list \
		|| mk_fail "Bucket '$_bucket' is not valid"
done
mk_msg "BUCKETS: ${buckets}"

mk_run date-picker -s "${startdate}" -e "${enddate}"
dates="$result"
mk_date_to_julian $startdate
s="$result"
mk_date_to_julian $enddate
e="$result"
_days=$(( ($e - $s) + 1 ))
mk_msg "DATERANGE: $_days"

while mk_read_line
do
#	mk_julian_to_date "$result"
	_date="$result"
	mk_date_to_julian "$result"
	_year="$YEAR"
	mk_unquote_list $buckets
	for _bucket
	do
		mk_set _metadir "${metadir}/${_bucket}/${_year}/${_date}"
		mk_set _file "${archivedir}/${_bucket}/${_year}/${_bucket}-${_date}.log.0001.gz"
		mk_absolute_path "${_metadir}"
		mk_set _metadir "$result"
		mk_absolute_path "${_file}"
		mk_set _file "$result"
		mk_absolute_path "${_metadir}/metadata"
		mk_set _metafile "$result"
		mk_absolute_path "${_metadir}/ips.txt"
		mk_set _ipfile "$result"

		if [ -f "${_file}" ]
		then
			mk_msg_debug "FOUND ${_file}"
		else
			mk_error "MISSING ${_file}"
			continue
		fi
		mk_run basename "${_file}"	
		_shortfile="$result"
		if [ -n "${verify}" ]
		then
			if mk_metafile_verify "${_metafile}"
			then
				mk_msg_verbose "${_metafile} VERIFY OK"
			else
				mk_set retcode 1
			fi
			continue
		fi

		if [ ! -d "${_metadir}"  ]
		then
			mk_mkdir "${_metadir}"
			mk_msg "Created ${_metadir}"
		fi

		if [ ! -f "${_metafile}" -o -n "${recheck}" ]
		then
			exec 6>"${_metafile}"
			mk_comment "${_file}"
			mk_run hostname
			hostname="$result"
			mk_emitf "HOSTNAME=%s\n" "${hostname}"
			mk_sha1 "${_file}"
			sha1_hash="$result"
			mk_emitf "FILE_SHA1=%s\n" "${sha1_hash}"
			mk_msg "SHA1(${_shortfile})=${sha1_hash}"
			mk_run stat -c "%n:%s:%u:%g:%U:%G:%a:%Y" "${_file}" 
			set -- `echo "$result" | mk_split ":"` 
			mk_set FILE "$1"
			mk_set FILE_SIZE "$2"
			mk_set FILE_UID "$3"
			mk_set FILE_GID "$4"
			mk_set FILE_USER "$5"
			mk_set FILE_GROUP "$6"
			mk_set FILE_MODE "$7"
			mk_set FILE_MTIME "$8"
			for i in \
				FILE FILE_SIZE FILE_UID FILE_GID FILE_USER \
				FILE_GROUP FILE_MODE FILE_MTIME
			do
				mk_get "$i"
				mk_emitf "%s=%s\n" "$i" "$result"
			done
			exec 6>&-
		fi
		if [ ! -f "${_ipfile}.gz" -o -n "${recheck}" ]
		then
			exec 7>"${_ipfile}"
			{
				$P_GZIP -dc "${_file}" \
				| $P_EXTRACTIPS \
				| $P_NORMALIZEIPS \
				| $P_BADIPS \
				| $P_DEDUPIPS;
			} >&7

			exec 7>&-
			mk_msg "Wrote ${_ipfile}"
			mk_msg "Compressing ${_ipfile}"
			mk_run $P_GZIP -9f "${_ipfile}"
			mk_set _ipfile "${_ipfile}.gz"
			mk_sha1 "${_ipfile}"
			sha1_hash="$result"
			exec 6>>"${_metafile}"
			mk_emitf "IPFILE=%s\n" "${_ipfile}"
			mk_emitf "IPFILE_SHA1=%s\n" "${sha1_hash}"
			exec 6>&-
			mk_msg "SHA1(${_shortfile}/$(basename ${_ipfile}))=${sha1_hash}"
		fi
		mk_msg_verbose "Wrote ${_metafile}"
	done
done < <(echo "${dates}")
mk_msg "FINISH: `date`"
exit $retcode

: <<=cut

=pod

=head1 NAME

find-latest-logs: find the latest logs

=head1 USAGE

find-latest-logs [-h|--help] [ARG...]

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

=back

=over

=item -e, --enddate

The enddate for the search (default: today)
Dates are in the form of YYYYMMDD

=back

=over

=item -m, --metadir

The location for the metadata files

=back

=over

=item -a, --archivedir

The root location of the logfiles

=back

=over

=item -b bucket[,bucket..], --bucket bucket[,bucket..]

Which buckets to scan. Defaults to ALL if nothing set.

=back

=over

=item -o outfile, --outfile <outfile>

Log the output to <outfile>

=back

=over

=item --verify

Verifies that metadata files are intact and reports errors

=back

=over

=item --recheck

Force recreation of metadata files

=back

=over

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
