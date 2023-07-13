#
# module/common.sh
#
# Common makekit routine not supplied with core
#

_mk_declare_exported()
{
	case " $MK_EXPORTS " in
		*" $1 "*)
			return 0
			;;
	esac

	MK_EXPORTS="$MK_EXPORTS $1"
}

mk_unique_list()
{
	mk_unique | xargs
}

hostname_only ()
{
	cut -d: -f1
}

mk_unique ()
{
	mk_list | sort | uniq
}

mk_hardlink_count ()
{
	perl -le 'print ((stat("'"$1"'"))[3])'
}

mk_hostfqdn (){
	perl -MNet::Domain=hostfqdn -le 'print hostfqdn'
}

mk_hostdomain ()
{ 
	perl -MNet::Domain=hostdomain -le 'print hostdomain'
}


mk_list ()
{
	_sep="${1:- }"
	xargs | awk 'BEGIN { RS="'"$_sep"'"; } { print $1; }'
}

mk_split ()
{
	_sep="${1:- }"
	xargs | awk 'BEGIN { FS="'"$_sep"'"; } { $1=$1; print; }'
}

mk_error()
{
	mk_msg "ERROR: $@" >&2
	return 1
}

mk_fail()
{
    mk_error "$@"
    exit 1
}

mk_toupper ()
{
	tr '[:lower:]' '[:upper:]'
}

mk_lower ()
{
	tr '[:upper:]' '[:lower:]'
}

mk_escape_slash ()
{
	sed -e 's/\//\\\//g'
}

mk_help ()
{
	if [ -n "$P_POD2USAGE" ]; then
		PERL5LIB= $P_POD2USAGE -verbose 0 -exit 1 "$SELF"
	else
		mk_msg "Type '${PROGNAME%*.sh} --help' for usage"
	fi
	exit 1
}

mk_usage () 
{
	if [ -n "$P_POD2USAGE" ]; then
		PERL5LIB= $P_POD2USAGE -verbose 1 -exit 1 "$SELF"
	fi
	exit 1
}

mk_man ()
{
	if [ -n "$P_POD2USAGE" ]; then
		PERL5LIB= $P_POD2USAGE -verbose 3 -exit 1 "$SELF"
	fi
	exit 1
}

mk_irun()
{
	mk_quote_list "$@"
	mk_msg_debug "EXEC: $result"
	if [ -n "$MK_DRYRUN" ]; then
		set -- "/bin/true" "$@"
	fi
	_log="`"$@" 3>&1 1>&2 2>&3 3>&- && _junk=$? | tee >(cat - >&2)`"
	_code=$?
	mk_msg_debug "RETURN CODE: $_code"

	if [ "$_code" -ne 0 ]; then
		mk_msg_debug "FAILED: $result" >&2
		_status=1
	fi
	mk_msg_debug "$_log"
	result="${_log}"
	return $_code
}

mk_run()
{
	mk_quote_list "$@"
	mk_msg_debug "EXEC: $result"
	if [ -n "$MK_DRYRUN" ]; then
		set -- "/bin/true" "$@"
	fi
	_log="`"$@" 2>&1`"
	_code=$?
	_status=
	mk_msg_debug "RETURN CODE: $_code"
	if [ "$_code" -ne 0 ]; then
		echo "$__log" >&2
		mk_log "$_log"
		mk_msg_debug "FAILED: $_log" >&2
		_status=1
	fi
#	mk_msg_verbose "$_log"
	result="$_log"
	return $_code
}

find_program ()
{
	result=
	for _prog
	do
		_IFS="$IFS"
		IFS=":"
		for _dir in ${PATH}
		do
			if [ -x "${_dir}/${_prog}" ]
			then
				result="${_dir}/${_prog}"
				break
			fi
		done
		IFS="$_IFS"
		[ -n "$result" ] && break
	done
	[ -n "$result" ]
}

version ()
{
	printf "%s: version %s\n" "${PROGNAME%*.sh}" "$VERSION"
	exit 1
}

# return the fully qualified domain name of specified host
get_fqdn() {
	_addr=`getent hosts "$1" 2>/dev/null | awk '{print $1}'`
	[ -n "$_addr" ] || mk_error host "$1" not found in the name space

	if [ -f /usr/sbin/dig -o -f /usr/bin/dig ]
	then
		_fqdn=`(dig -x "$_addr" +short | sed 's/\.$//')`
	elif [ -f /bin/host -o -f /usr/bin/host -o -f /sbin/host \
		-o -f /usr/sbin/host ]
	then
		_fqdn=`host "$_addr" 2>/dev/null \
			| awk '{print $5}' | sed 's/\.$//'`
	else
		_fqdn=`nslookup "$_addr" 2>/dev/null \
			| grep Name: | awk '{print $2}'`
	fi

	[ -n "$_fqdn" ] || mk_error unable to determine FQDN for host "$1"
	echo "$_fqdn"
}

# return the fully qualified domain name of host on which we are running
get_myfqdn() {
	get_fqdn `hostname`
}

find_program pod2text && P_POD2TEXT="$result"

find_program pod2usage && P_POD2USAGE="$result"

find_program perl && P_PERL="$result"

HOSTNAME=`hostname`
FQDN=`get_myfqdn`

_MK_MKTEMP_LIST=""

mk_mktemp ()
{
	_result=
	_tag="$MK_COMMAND"
	[ -n "$1" ] && _tag="$1"
		
	mk_run mktemp -t ".${_tag}.$$.XXXXX" \
		|| mk_fail "$result"
	_result="$result"
	mk_quote "$_result"
	_MK_MKTEMP_LIST="$_MK_MKTEMP_LIST $result"
	mk_msg_debug "Created tempfile $result"
	result="$_result"
}

mk_mktempd ()
{
	_result=
	_tag="$MK_COMMAND"
	[ -n "$1" ] && _tag="$1"
		
	mk_run mktemp -d -t ".${_tag}.$$.XXXXX" \
		|| mk_fail "$result"
	_result="$result"
	mk_quote "$_result"
	_MK_MKTEMP_LIST="$_MK_MKTEMP_LIST $result"
	mk_msg_debug "Created temp directory $result"
	result="$_result"
}

mk_mktemp_delete ()
{
    mk_unquote_list "$_MK_MKTEMP_LIST"
    _MK_MKTEMP_LIST=""
    for _tmp
    do
	if [ "$_tmp" = "$1" ]
	then
	    mk_run rm -rf -- "$_tmp" \
		|| mk_error "Failed to remove $_tmp"
	else
	    mk_quote "$_tmp"
	    _MK_MKTEMP_LIST="$_MK_MKTEMP_LIST $result"
	fi
    done
}

mk_mktemp_clear ()
{
    mk_unquote_list "$_MK_MKTEMP_LIST"
    _MK_MKTEMP_LIST=""
	mk_get no_cleanup
	_no_cleanup="$result"
    for _tmp
    do
		if [ -z "$no_cleanup" ]; then
			mk_run rm -rf -- "$_tmp" \
				|| mk_error "Failed to remove $_tmp"
		else
			mk_msg "$_tmp not deleted"
		fi	
    done
}

mk_tempfile_clear()
{
    mk_unquote_list "$_MK_TMPLIST"
    _MK_TMPLIST=""
    for _tmp
    do
		if [ -z "$no_cleanup" ]; then
			mk_run rm -rf -- "$_tmp" \
				|| mk_error "Failed to remove $_tmp"
		else
			mk_msg "$_tmp not deleted"
		fi	
    done
}

cleanup () 
{
	_code="$1"
	if [ -n "$O_HELP" ]; then return; fi 
	mk_msg_domain "cleanup"
	mk_msg_verbose "Cleaning up"

	for i in skipme $CLEANUP
	do
		case "$i" in skipme*) continue;; esac
		mk_msg_verbose "Calling ${i}"
		$i
	done
	mk_get logfile
	_logfile="$result"
	if [ -n "$_logfile" ]; then
		mk_msg_domain ""
		mk_msg_verbose ""
		mk_msg_verbose "Output logged to ${BASEDIR}/${_logfile}"
	fi
	mk_tempfile_clear
	mk_mktemp_clear
	exit $_code
}

trap 'cleanup $?' EXIT
trap 'cleanup 130' INT
trap 'cleanup 143' TERM

_mk_declare_exported()
{
	case " $MK_EXPORTS " in
		*" $1 "*)
			return 0
			;;
	esac

	MK_EXPORTS="$MK_EXPORTS $1"
}

mk_quiet ()
{
	mk_push_vars QUIET
	mk_parse_params

	if [ -n "$MK_QUIET" ] ; then	
		_mk_msg_checking="mk_log_checking"
		_mk_msg_result="mk_log_result"
		_mk_msg="mk_log"
	elif [ -z "$QUIET" ]; then
		_mk_msg_checking="mk_msg_checking"
		_mk_msg_result="mk_msg_result"
		_mk_msg="mk_msg"
	else
		_mk_msg_checking="mk_log_checking"
		_mk_msg_result="mk_log_result"
		_mk_msg="mk_log"
	fi
	mk_pop_vars
}

mk_warning_msg() 
{
	(cat  <<EOF) | while read line ; do mk_msg "$line"; done
	
###########################################

#    #   ##   #####  #    # # #    #  ####  
#    #  #  #  #    # ##   # # ##   # #    # 
#    # #    # #    # # #  # # # #  # #      
# ## # ###### #####  #  # # # #  # # #  ### 
##  ## #    # #   #  #   ## # #   ## #    # 
#    # #    # #    # #    # # #    #  ####  

###########################################

EOF
}

mk_check_program()
{
	mk_push_vars VAR PROGRAM FAIL QUIET
	mk_parse_params

	if [ -z "$PROGRAM" ]
	then
		PROGRAM="$1"
		shift
	fi

	if [ -z "$VAR" ]
	then
		_mk_define_name "$PROGRAM"
		VAR="$result"
	fi

	set -- "$PROGRAM" "$@"

	mk_get "$VAR"
	[ -n "$result" ] && set -- "$result" "$@"

	_res=""

	mk_quiet QUIET=$QUIET

	for _cand
	do
		$_mk_msg_checking "Checking for program ${_cand##*/}"
		if _mk_contains "$_cand" "$MK_INTERNAL_PROGRAMS"
		then
			$_mk_msg_result "(internal)"
			_res="${MK_RUN_BINDIR}/${_cand}"
			break
		elif [ -x "$_cand" ]
		then
			_res="$_cand"
			$_mk_msg_result "$_cand"
			break
		else
			_IFS="$IFS"
			IFS=":"
			for __dir in ${MK_PATH} ${PATH}
			do
				if [ -x "${__dir}/${_cand}" ]
				then
					_res="${__dir}/${_cand}"
					$_mk_msg_result "$_res"
					break
				fi
			done
			IFS="$_IFS"
		fi
		[ -n "$_res" ] && break
		$_mk_msg_result "no"
	done

	if [ -z "$_res" -a "$FAIL" = "yes" ]
	then
		mk_fail "could not find program: $PROGRAM"
	fi

	mk_declare -e "$VAR=$_res"

	mk_pop_vars
	[ -n "$_res" ]
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

mk_append_string ()
{
	__var="$1"
	__sep="${__sep:- }"
	shift
	mk_get "${__var}"
	[ -z "$result" ] && __sep=
	#[ $# -gt 0 ] && mk_set "${__var}" "${result}${__sep}$@"
	mk_set "${__var}" "${result}${__sep}$@"
	mk_get "${__var}"
	unset __var __sep
}

mk_tempfile()
{
	_tag="$MK_COMMAND"

	_result="${TMPDIR:-/tmp}/.${_tag}.$$.$_MK_TMPCOUNT.$1"
	_MK_TMPCOUNT=$(($_MK_TMPCOUNT+1))
	mk_quote "$_result"
	_MK_TMPLIST="$_MK_TMPLIST $result"
	result="$_result"
}


mk_yorn()
{
	response=""

	while true
	do
		printf "%s (y/n): " "$1"
		read response
		case "$response" in
			[yY]*)
				return 0
				;;
			[nN]*)
				return 1
				;;
		esac
	done
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

mk_append_string ()
{
    __var="$1"
    shift
    mk_get "${__var}"
    [ $# -gt 0 ] && mk_set "${__var}" "${result} $@"
    mk_get "${__var}"
    unset __var
}

mk_file_is_dos ()
{
	__file="$1"
	awk '/\r$/{exit 0;} 1{exit 1;}' "$__file" >/dev/null 2>&1
	return $?
}

mk_file_is_unix ()
{
	! mk_file_is_dos "$@"
}

mk_dos2unix ()
{
	perl -pe 's/\r\n/\n/g' $@ 
}

mk_unix2dos ()
{
	perl -pe 's/\n/\r\n/g' $@
}

mk_emit()
{
    echo "$@" >&6
}

mk_emitf()
{
    printf "$@" >&6
}

mk_comment()
{
    mk_emitf "\n#\n# %s\n#\n" "$*"
}

mk_sha1()
{
	_result=
	mk_run openssl sha1 "$1"
	_result="`echo $result | awk '{ print $2 }'`"
	result="$_result"
}

mk_resolve_ips()
{
	if [ -n "${do_resolve_ips}" ]
	then
		$P_RESOLVEIPS
	else
		cat
	fi
}
