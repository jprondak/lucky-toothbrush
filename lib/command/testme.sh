#!/bin/ksh -px

PROGNAME=${0##*/}
BASEDIR=$(cd $(dirname $0); pwd)
PARENT=$(cd $(dirname $BASEDIR); pwd)
SELF="$(cd $(dirname $0); pwd)/$PROGNAME"
REVISION='$Revision: 9058 $'
VERSION=$(echo $REVISION | sed -e 's/^\$Revision.* \([0-9]*\) .*/\1/')

[ "$REVISION" = "$VERSION" ] && VERSION=
: ${VERSION:=1}

#STARTDATE=
#ENDDATE=
#MERGEDIR=
#EVENTLOG=
EVENTLOGS=

COMMONFUNCS=${MK_HOME}/init.sh

if test -f $COMMONFUNCS
then
	. $COMMONFUNCS
else
	echo "ERROR: Could not load $COMMONFUNCS"  >&2
	exit 1
fi

set -- $@

while [[ $# -gt 0 ]]
do
	case "$1" in
	-C|--config)
		[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
		mk_set PBSEARCH_CONFIG "$2"
		shift
		;;
	-s|-f|--startdate)
		[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
		mk_set STARTDATE "$2"
		shift
		;;
	-e|-t|--enddate)
		[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
		mk_set ENDDATE "$2"
		shift
		;;
	-u|--user|--runuser)
		[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
		mk_append_list RUNUSERS "$2"
		shift
		;;
	-U|--requestuser)
		[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
		mk_append_list SUBMITUSERS "$2"
		shift
		;;
	-h|--host|--runhost)
		[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
		mk_append_list RUNHOSTS "$2"
		shift
		;;
	-H|--submithost)
		[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
		mk_append_list SUBMITHOSTS "$2"
		shift
		;;
	-c|--command)
		[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
		mk_append_list COMMANDS "$2"
		shift
		;;

	-m|--mergedir)
		[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
		mk_set MERGEDIR "$2"
		shift
		;;
#	-f|--eventlog)
#		[ $# -gt 1 ] || mk_fail "Option '$1' requires an argument"
#		mk_set EVENTLOG "$2"
#		shift
#		;;
	-a|--accept)
		mk_set O_ACCEPT 1
		;;
	-A|--reject)
		mk_set O_REJECT 1
		;;
	-e|--stderr)
		mk_set O_STDERR 1
		;;
	-o|--stdout)
		mk_set O_STDOUT 1
		;;
	-i|--stdin)
		mk_set O_STDIN 1
		;;
	-X|--debug)
		mk_set MK_DEBUG 1
		;;
	-F|--fail-on-error)
		mk_set FAIL_ON_ERROR 1
		;;
	-v|--verbose)
		mk_set MK_VERBOSE 1
		;;
	--help)
		mk_usage
		;;
	--man)
		mk_man
		;;
	-l)
		mk_set O_LIST_EVENTLOGS 1
		;;
	-L)
		mk_set O_LIST_IOLOGS 1
		;;
	-V|--version)
		version;;
	*)
		break
		#mk_error "Invalid option '$1'"
		#mk_help
		;;
	esac
	shift
done

mk_contraint_slist () {
	mk_get "$1"
	mk_unquote_list "$result"

	x=1
	n=$#
	result=
	while [ $x -lt $n ]
	do
		result="$result\"$1\","
		shift
		x=$((x+1))
	done
	if [ $# -gt 0 ]
	then
		result="$result\"$1\""
		shift
	fi
}

mk_contraint_IN ()
{
	mk_contraint_slist "$2"
	result="($1 in {$result})"
}

mk_constraint_AND ()
{
	mk_append_list "$1" "&&"
}

mk_constraint_OR ()
{
	mk_append_list "$1" "||"
}

mk_error_or_fail ()
{
	if [ -n "$FAIL_ON_ERROR" ]
	then
		mk_fail "$@"
	else
		mk_error "$@"
	fi
}

pblog_constraint ()
{
	__op="$1"
	shift
	__var="$1"
	shift
	mk_get "${__var}"
	[ -n "${result}" ] || __op=
	mk_set "${__var}" "${result}${__op}$@"
	unset __var __op
}

pblog_constraint_OR ()
{
	pblog_constraint "||" $@	
}

pblog_constraint_AND ()
{
	pblog_constraint "&&" "$@"
}

pblog_constraint_IN ()
{
	result=
	__var="$1"
	shift
	__list=
	for __arg
	do
		[ -n "${__list}" ] && __list="${__list},"
		 __list="${__list}\"${__arg}\""
	done
	[ -n "${__list}" ] && result="(${__var} in {$__list})"
}

mk_append_string ()
{
	__var="$1"
	shift
	mk_get "${__var}"
	[ $# -gt 0 ] && mk_set "${__var}" "${result} $@"
	mk_get "${__var}"
	unset __var
}

mk_pblog_constraint ()
{
	PATTERN=
	#mk_append_list PATTERN '(isset("iolog") && length(iolog))'
	mk_append_string PATTERN "(isset(\"iolog\") && length(iolog))"

	__EVENTS=
	[ -n "$O_ACCEPT" ] && mk_append_string __EVENTS "Accept"
	[ -n "$O_REJECT" ] && mk_append_string __EVENTS "Reject"
	
	if [ -n "$__EVENTS" ]
	then
		pblog_constraint_IN event $__EVENTS
		pblog_constraint_AND PATTERN "$result"
	fi

	unset __EVENTS

	if [ -n "$SUBMITUSERS" ]
	then
		SUBMITUSERS="`echo $SUBMITUSERS | mk_unique_list`"
		pblog_constraint_IN requestuser $SUBMITUSERS
		pblog_constraint_AND PATTERN "$result"
	fi

	_SUBMITHOSTS=
	if [ -n "$SUBMITHOSTS" ]
	then
#		mk_unquote_list "$SUBMITHOSTS"
		for h in skipme `echo $SUBMITHOSTS | mk_unique_list`
		do
			case $h in skipme) continue;; esac
			if mk_run $P_FQDN $h
			then
				mk_append_string _SUBMITHOSTS "$result"
			else
				mk_error_or_fail "FQDN submithost '$h' ($result)"
			fi
		done
		if [ -n "$_SUBMITHOSTS" ]
		then
			pblog_constraint_IN submithost $_SUBMITHOSTS
			pblog_constraint_AND PATTERN "$result"
		fi
	fi
	unset _SUBMITHOSTS

	if [ -n "$RUNUSERS" ]
	then
		RUNUSERS="`echo $RUNUSERS | mk_unique_list`"
		pblog_constraint_IN runuser $RUNUSERS
		pblog_constraint_AND PATTERN "$result"
	fi

	_RUNHOSTS=
	if [ -n "$RUNHOSTS" ]
	then
#		mk_unquote_list "$RUNHOSTS"
		for h in skipme `echo $RUNHOSTS | mk_unique_list`
		do
			case $h in skipme) continue;; esac
			if mk_run $P_FQDN $h
			then
				mk_append_string _RUNHOSTS "$result"
			else
				mk_error_or_fail "FQDN runhost '$h' ($result)"
			fi
		done
		if [ -n "$_RUNHOSTS" ]
		then
			pblog_constraint_IN runhost $_RUNHOSTS
			pblog_constraint_AND PATTERN "$result"
		fi
	fi
	unset _RUNHOSTS

	if [ -n "$COMMANDS" ]
	then
		COMMANDS="`echo $COMMANDS | mk_unique_list`"
		pblog_constraint_IN runcommand $COMMANDS
		pblog_constraint_AND PATTERN "$result"
	fi
	result="$PATTERN"
}
foo () {


	mk_unquote_list "$PATTERN"
	P=
	while [ $# -gt 1 ]
	do
			mk_msg "$#: $1"
			P="$P $1 &&"
			shift
	done
	P="$P $1"
	#mk_quote "$P"
	#mk_msg "P=$result"
	mk_append_list _result "$P"
	result="$_result"
	#mk_msg "PATTERN=$PATTERN"
}

export STARTDATE ENDDATE MERGEDIR
case "$1" in
	config)
		shift
		mk_check_program VAR=P_PBSEARCH_CONFIG FAIL=yes QUIET=1 pbsearch-config
		exec $P_PBSEARCH_CONFIG $@
		;;
	eventlog*)
		shift
		mk_check_program VAR=P_PBSEARCH_EVENTLOGS FAIL=yes QUIET=1 pbsearch-eventlogs
		exec $P_PBSEARCH_EVENTLOGS
		;;
esac

#mk_check_program VAR=P_PBSEARCH_EVENTLOGS FAIL=yes QUIET=1 pbsearch-eventlogs
#mk_check_program VAR=P_PBLOGZ FAIL=yes QUIET=1 pblogz
#mk_check_program VAR=P_FQDN FAIL=yes QUIET=1 fqdn
#
#mk_tempfile eventlogs
#L_EVENTLOGS="$result"
##mk_msg_debug "Writing eventlog list to $L_EVENTLOGS"
#mk_tempfile pblog
#L_PBLOG="$result"
#mk_msg_debug "Writing pblog output to $L_PBLOG"
#mk_pblog_constraint
#constraint="$result"
#mk_capture_lines $P_PBSEARCH_EVENTLOGS
#echo "$result" > oo
#mk_msg_debug "Running $P_PBLOGZ"
#mk_unquote_list "$result"
#$P_PBLOGZ $@ -- -c "$constraint"  -p 'sprintf("%s:%s",logservers[0],iolog)' > $L_PBLOG
#cp $L_PBLOG o
exit 0

: <<=cut

=pod

=head1 NAME

pbsearch: Search PowerBroker event and iologs for matches

=head1 SYNOPSIS

pbsearch [options]

pbsearch [options] [ config | eventlog ]

pbsearch [--help]

pbsearch --man

=head1 OPTIONS

=over

=item --help

Help information

=back

=over

=item --man

Print man page

=back

=over

=item -C, --config

Configuration file to use instead of default.
(default: /etc/opt/pbsearch/pbsearch.conf)

=back

=over

=item -u, --user, --runuser

The runuser to search for.

=back

=over

=item -U, --submituser

The submituser to search for.

=back

=over

=item -h, --host, --runhost

The runhost to search for.

=back

=over

=item -H, --submithost

The submithost to search for.

=back

=over

=item -l

List the eventlogs to search and exit

=back

=over

=item -L

List the iologs to search and exit

=back

=over

=item -m, --mergedir

The location of the MERGED eventlogs (default: /var/log/pb/MERGE)

(Also follows the MERGEDIR environment variable)

=back

=over

=item -V, --version

Display Version

=back

=head1 ENVIRONMENT

If the environmental variable KRB5_CONFIG is set, that will be used as the location of the krb5.conf

=head1 OUTPUT

A list of eventlogs are returned on STDOUT

Errors are reported on STDERR

=head1 EXAMPLE

  $ pbsearch -s 20140119 -e 20140126 
  /var/log/pb/MERGE/20140120/pb.eventlog.ALL.gz
  /var/log/pb/MERGE/20140121/pb.eventlog.ALL
  /var/log/pb/MERGE/20140122/pb.eventlog.ALL.bz2
  /var/log/pb/MERGE/20140123/pb.eventlog.ALL
  /var/log/pb/MERGE/20140124/pb.eventlog.ALL.gz
  /var/log/pb/MERGE/20140125/pb.eventlog.ALL.gz
  /var/log/pb/MERGE/20140126/pb.eventlog.ALL.gz


=head1 EXIT STATUS

The following exit values are returned:

0   			Successful operation

non-zero		An error has occurred.

=head1 AUTHOR

Jason Prondak, E<lt>jprondak.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014

This library is free software; you can redistribute it and/or modify
it.

=cut
