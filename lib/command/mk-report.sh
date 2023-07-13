#!/bin/bash
#
# mk-report
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
		metadir logdir inputfile outputfile outputdir
	do
		mk_get "$i"
		mk_msg "$i = $result"
	done
	exit 0;
}

#inputfile="${srcfile:=Devices.csv}"
mk_tempfile "outputfile"
mk_set outputfile "$result"
mk_get MK_COMMAND
cmd="$result"
result=
mk_set outputdir "$(pwd)"

while [[ $# -gt 0 ]]
do
	case "$1" in
		--csv)
				[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
				mk_set csvfile "$2"
				shift
				;;
		-i|--input)
				[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
				mk_set inputfile_orig "$2"
				shift
				;;
		-d|--outputdir)
				[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
				mk_set outputdir "$2"
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
		-m|--metadir)
				[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
				mk_set metadir "$2"
				shift
				;;
		-b|--bucket)
				[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
				mk_append_list buckets "$2"
				shift
				;;
		--dns)
				mk_set do_resolve_ips 1
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
		--keep)
				mk_set no_cleanup 1
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

if [[ -n "${outputfile}" ]]
then
	exec 4>${outputfile}
	MK_LOG_FD=4
fi

mk_absolute_path "${metadir}"
mk_set metadir "$result"

if [ -n "${inputfile_orig}" ]
then
	mk_set inputfile "${inputfile_orig}"
	mk_absolute_path "${inputfile_orig}"
	mk_set inputfile "$result"
fi

mk_get print_defaults
[ -n "$result" ] && _print_defaults

[ -n "${inputfile}" ] || mk_fail "No inputfile supplied"
[ -f "${inputfile}" ] || mk_fail "An INPUT file '${inputfile}' does not exist"

mk_msg "START: `date`"
mk_msg "INPUTFILE: ${inputfile}"
mk_msg "METADIR: ${metadir}"
mk_msg "ARCHIVEDIR: ${archivedir}"
mk_msg "STARTDATE: ${startdate}"
mk_msg "ENDDATE: ${enddate}"
mk_date_to_julian $startdate
s="$result"
mk_date_to_julian $enddate
e="$result"
_daterange=$(( ($e - $s) + 1 ))

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

[ -d "${metadir}" ] || mk_fail "METADIR: ${metadir} does not exist"
[ -f "${inputfile}" ] || mk_fail "INPUTFILE: ${inputfile} does not exist"

if mk_file_is_dos "${inputfile}"; then
	mk_msg "${inputfile} is DOS. Converting"
	mk_tempfile "inputfile"
	{ mk_dos2unix "${inputfile}"; } > "$result" 2>&${MK_LOG_FD}
	mk_set inputfile "$result"
fi

mk_tempfile "reference"
mk_set reference "$result"
{
	$P_DUMPCSVIPS "${inputfile}" \
	| $P_NORMALIZEIPS \
	| $P_BADIPS \
	| $P_DEDUPIPS > "${reference}";
} >&${MK_LOG_FD} 2>&${MK_LOG_FD}
mk_msg "Wrote Normalized INPUT"

mk_msg "Scanning METADATA in ${metadir}"

bucket_list=
mk_tempfile "daterange"
mk_set daterange "$result"

{
	mk_run $P_PICKER -s "${startdate}" -e "${enddate}" > "$daterange"
	daterange="$result"
	mk_msg "DATERANGE: $_daterange"
	_needed=0
	_found=0
	missing_buckets=
	while mk_read_line
	do
		_date="$result"
		mk_date_to_julian "$result"
		_year="$YEAR"
		mk_unquote_list $buckets
		for _bucket
		do
			_needed=$(( _needed + 1 ))
			mk_absolute_path "${metadir}/${_bucket}/${_year}/${_date}"
			mk_set _metadir "$result"
			mk_absolute_path "${_metadir}/metadata"
			mk_set _metafile "$result"
			mk_absolute_path "${_metadir}/ips.txt"
			mk_set _ipfile "$result"
	
			if [ ! -f "${_metafile}" ]
			then
				mk_error "BAD BUCKET: ${_bucket}/${_year}/${_date}"
				mk_append_list missing_buckets "${_bucket}/${_year}/${_date}"
				continue
			fi
	
			if ! mk_metafile_verify "${_metafile}"
			then
				continue
			fi
			mk_msg_verbose "IPFILE: ${_bucket}/${_year}/${_date}"
			_found=$(( _found + 1 ))
			mk_append_list bucket_list "$_ipfile"
		done
	done < <(echo "$daterange") ;
}
# >&${MK_LOG_FD} 
#2>&${MK_LOG_FD}

mk_msg "IPFILEs Needed: $_needed"
mk_msg "IPFILEs Found: $_found"

mk_tempfile "ipcache"
mk_set ipcache "$result"
mk_msg "Merging IPs"

{
	mk_unquote_list $bucket_list
	$P_GZIP -dc -v $@ \
	| $P_NORMALIZEIPS \
	| $P_BADIPS \
	| $P_DEDUPIPS;
} > "${ipcache}" 2>&${MK_LOG_FD}

[ -n "${do_resolve_ips}" ] && mk_msg "IPs DNS Resolution enabled"

mk_tempfile "found-ips"
mk_set foundips "$result"

{
	$P_FOUNDIPS "${reference}" "${ipcache}" \
		| mk_resolve_ips > "${foundips}";
} >&${MK_LOG_FD} 2>&${MK_LOG_FD}
mk_tempfile "missing-ips"
mk_set missingips "$result"
{
	$P_MISSINGIPS "${reference}" "${ipcache}" \
		|  mk_resolve_ips > "${missingips}";
} >&${MK_LOG_FD} 2>&${MK_LOG_FD}

mk_mktempd "zipdir"
mk_set zipdir "$result"
destdir="$MK_COMMAND-s${startdate}-e${enddate}-`date '+%Y%m%d%H%M%S'`"

mk_run mk_mkdir "${zipdir}/${destdir}"

mk_run cp "${inputfile_orig}" "${zipdir}/${destdir}" \
	|| mk_fail "Could not copy ${inputfile} to ${destdir}"

mk_run cp "${foundips}" "${zipdir}/${destdir}/found-ips.csv" \
	|| mk_fail "Could not copy ${foundips} to ${destdir}"

mk_run cp "${missingips}" "${zipdir}/${destdir}/missing-ips.csv" \
	|| mk_fail "Could not copy ${missingips} to ${destdir}"

mk_run cp "${outputfile}" "${zipdir}/${destdir}/output.txt" \
	|| mk_fail "Could not copy ${outputfile} to ${destdir}"
(
	cd "${zipdir}"
	mk_run $P_ZIP -l -r "${destdir}" "${destdir}.zip" . \
		|| mk_fail "Could not write ${zipdir}/${destdir}.zip"
	mk_msg_verbose "Created ${zipdir}/${destdir}.zip"
)
mk_run mv "${zipdir}/${destdir}.zip" "${outputdir}" \
	|| mk_fail "Could not mv ${zipdir}/${destdir}.zip to ${outputdir}"
mk_msg "Report located in ${outputdir}/${destdir}.zip"  

mk_msg "FINISH: `date`"
exit 0

: <<=cut

=pod

=head1 NAME

mk-report: Generate a IP report

=head1 USAGE

mk-report [-h|--help] [ARG...]

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

=item -i inputfile, --input <inputfile>

Use the CSV data in <inputfile> as the data reference

=back

=over

=item -d outputdir, --outputdir <outputdir>

Put the resulting zip file in this directory (default: cwd)

=back

=over
 
=item -b bucket[,bucket..], --bucket bucket[,bucket..]

Which buckets to scan. Defaults to ALL if nothing set.

=back

=over

=item --dns

Do DNS Reverse Resolution on hosts in the found and missing output files

=back

=over

=item --defaults

Print runtime environment infomation

=back

=over

=item --keep

Keep temporary files around for debugging

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
