#
# module/logging.sh
#
# Changes to makekit core logging functions
#
##
#
# mk_msg_format
#
# Prints a message with pretty formatting.  The user could
# import a module to override this if they so desired...
#
# $1 = message domain
# $2 = message
#
##
mk_msg_format()
{
	if [ -z "$1" -o -z "$MK_MSG_DOMAIN" ]
	then
		printf "%s\n" "$2"
	else
		printf "%-10s %s\n" "[$1]" "$2"
	fi
}

mk_msg_format_begin()
{
	if [ -z "$1" -o -z "$MK_MSG_DOMAIN" ]
	then
		printf "%s" "$2"
	else
		printf "%-10s %s" "[$1]" "$2"
	fi
}

mk_log_checking()
{
	mk_log_begin "$*: "
}

mk_log_result()
{
	mk_log_end "$*"
}

mk_msg_debug ()
{
	[ -n "${MK_DEBUG}" ] && mk_msg "$@" >&2
}

mk_log_debug()
{
	[ -n "${MK_DEBUG}" ] && mk_log "$@"
}

mk_log_checking()
{
	mk_log_begin "$*: "
}

mk_log_result()
{
	mk_log_end "$*"
}

mk_checking_error ()
{
	mk_push_vars ERROR FAIL QUIET
	mk_parse_params
	
	mk_quiet QUIET=$QUIET
	
	if [ -z "$ERROR" ]; then
		ERROR="$1"
	fi
	
	$_mk_msg_checking "$1"
	$_mk_msg_result "FAILED"
	
	if [ "$FAIL" = yes ]; then
		mk_fail "$ERROR"
	fi
	
	mk_pop_vars
	[ 1 = 0 ]
}

mk_quiet ()
{
	mk_push_vars QUIET
	mk_parse_params
	
	if [ -z "$QUIET" ]; then
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

