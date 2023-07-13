#
# module/ini.sh
#
# Routines to handle INI style files
#
#
# This code stolen from Merlin Mathesius (merlinm)'s sc-proxy code
#
# It is so simple that is makes me mad that I did not think of it first. :)
# I was using sed too, but I think the normalize_conf was the piece I missed 
# out on. Cheers Merlin.  --prondajb
#
# functions for parsing ini configuration file
_ini_normalize_data ()
{
	sed \
		-e :a -e '/\\$/N; s/[ 	]*\\\n[ 	]*/ /; ta' \
		-e 's/[ 	]*\=[ 	]*/=/g' \
		-e 's/^[ 	]*//' \
		-e 's/#.*$//' \
		-e 's/[ 	]*$//' \
		-e '/^$/d'
}

_ini_normalize_conf ()
{
	cat "$1" | _ini_normalize_data
}

check_ini_conf ()
{
	[ -n "$1" ] || mk_fail "NULL filename"
	[ -f "$1" ] || mk_fail "'$1' file not found"
	[ -r "$1" ] || mk_fail "'$1' permission denied"
}

process_ini_conf ()
{
	_ini_normalize_conf "$1"
}

_ini_list_sections ()
{
	sed -n -e '/^\[.*\]/{s/^\[\(.*\)\].*/\1/;p;}'
}

_ini_extract_section ()
{
	sed -n \
		-e '/^\['"$1"'\]/,/^\[/{ /^\[/!p; }'
}

_ini_extract_subsection ()
{
	sed -n \
		-e '/^'"$1"'={$/,/^}$/{ /[{}]$/!p; }'
}

_ini_extract_parameter ()
{
	sed -n \
		-e 's#^'"$1"'=\(.*\)$#\1#p'
}

ini_list_sections ()
{
	process_ini_conf "$1" \
		| _ini_list_sections
}

# get_parameter - fetch parameter from Kerberos configuration file
# Usage: get_parameter conffile section [subsection] parameter
ini_get_parameter()
{
	check_ini_conf "$1"
	case $# in
	2)
		ini_get_section "$1" "$2"
		;;
	3)
		ini_get_section "$1" "$2" | _ini_extract_parameter "$3"
		;;
	4)
		ini_get_section "$1" "$2" "$3" | _ini_extract_parameter "$4"
		;;
	*)
		mk_fail "Invalid arguments to ini_get_parameter()"
		;;
	esac
}

ini_get_section ()
{
	check_ini_conf "$1"
	case $# in
	2)
		process_ini_conf "$1" \
			| _ini_extract_section "$2"
		;;
	3)
		process_ini_conf "$1" \
			| _ini_extract_section "$2" \
			| _ini_extract_subsection "$3"
		;;
	*)
		mk_fail "Invalid arguments to ini_get_section()"
		;;
	esac
}

ini_get_mergedir ()
{
	check_ini_conf "$1"
	ini_get_parameter "$1" global mergedir
}

ini_get_admin_server ()
{
	check_ini_conf "$1"
	_realm=
	case $# in
	1)	
		_realm=`ini_get_default_realm "$1"`
		[ -n "$_realm" ] \
			|| mk_fail "no 'default_realm' defined in $1"
		;;
	2)
		_realm=$2
		;;
	*)
		mk_fail "Invalid arguments to ini_get_admin_server()"
		;;
	esac
	ini_get_parameter "$1" realms "$_realm" admin_server
}

list_servers ()
{
	check_ini_conf "$1"
	case $# in
	1)
		_realm=`ini_get_default_realm "$1"`
		[ -n "$_realm" ] \
			|| mk_fail "no 'default_realm' defined in $1"
		;;
	2)
		_realm=$2
		;;
	*)
		mk_fail "Invalid arguments to list_kdcs()"
		;;
	esac

	ini_get_parameter "$1" realms "$_realm" kdc
}
