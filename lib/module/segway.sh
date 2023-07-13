#
#
#
#
get_metadir()
{
	mk_get metadir
	[ -n "$result" ] && return 0
	return 1
}

get_archivedir()
{
	mk_get archivedir
	[ -n "$result" ] && return 0
	return 1
}

bucket_exists()
{
	_bucket="$1"
	[ -n "$_bucket" ] || mk_fail "bucket_exists: '$1' requires an argument"
	if ! get_archivedir
	then
		mk_error "bucket_exists: Could not get 'archivedir' variable"
		return 1
	fi	
	test -d "$result/$1" || return 1
	return 0
}

list_buckets()
{
	get_archivedir	|| mk_fail "Could not get 'archivedir' variable"
	{
		find "$result" \
			-maxdepth 2 \
			-type d \
			-name '[0-9][0-9][0-9][0-9]' \
			-exec dirname "{}" \; \
		| sort | uniq;
	} 2>/dev/null
}

list_bucket_names()
{
	list_buckets | xargs -ifname basename fname
}

list_bucket()
{
	_bucket="$1"
	if [ -z "$_bucket" ]
	then
		mk_error "list_bucket: 'bucket' was empty"
		retunr 1
	fi
	if [ -z "$_bucket" ]
	then
		mk_error "list_bucket: 'bucket' was empty"
		retunr 1
	fi
}

bucket_in_list()
{
	_bucket_list="$1"
	_buckets="$2"
}

check_buckets_exist()
{
	result=
	_ret=0
	mk_push_vars _buckets _bucket_list _bucket error
	_buckets="$1"
	error=no
	mk_set _bucket_list "`list_bucket_names | mk_unique_list`"
	if [ -z "${_buckets}" ]
	then
		mk_error "No buckets to scan"
		error=yes
	fi

	mk_unquote_list $_buckets
	for _bucket
	do
		if ! _mk_contains "$_bucket" $_bucket_list 
		then
			mk_error "Bucket '$_bucket' is not valid"
			result="$_bucket"
			error=yes
		fi
	done
	[ "$error" = yes ] && _ret=1
	mk_pop_vars
	return $_ret 
}

mk_metafile_verify()
{
	mk_push_vars \
		FILE FILE_SIZE FILE_UID FILE_GID FILE_USER \
		FILE_GROUP FILE_MODE FILE_MTIME FILE_SHA1 IPFILE IPFILE_SHA1 \
		_var _file _metafile _file_hash _ipfile_hash

	_metafile="$1"
	if [ ! -f "$_metafile" ]
	then
		mk_error "$_metafile does not exist"
		return 1
	fi
	mk_safe_source "$_metafile" \
		|| mk_fail "Failed to read '$_metafile'"
	for _var in \
		FILE FILE_SIZE FILE_UID FILE_GID FILE_USER \
		FILE_GROUP FILE_MODE FILE_MTIME FILE_SHA1 IPFILE IPFILE_SHA1
	do
		mk_is_set "$_var" || mk_fail "$_metafile has no '$_var' variable"
	done
	for _var in FILE IPFILE
	do
		mk_get "$_var"
		if [ -f "$_var" ]
		then
			mk_error "METAFILE: '$_var' ($result) does not exist"
			return 1
		fi
	done
	result=
	mk_sha1 "$FILE"
	if [ "$FILE_SHA1" != "$result" ]
	then
		mk_error "$FILE: FILE SHA1 mistmatch HAVE ($FILE_SHA1) GOT ($result)"
		return 1
	fi
	result=
	mk_sha1 "$IPFILE"
	if [ "$IPFILE_SHA1" != "$result" ]
	then
		mk_error "$IPFILE: IPFILE SHA1 mistmatch HAVE ($IPFILE_SHA1) GOT ($result)"
		return 1
	fi
	mk_pop_vars
	return 0
}

mk_init_metafile()
{
	mk_push_vars METAFILE
	mk_parse_params
	if [ -z "${METAFILE}" ]
    then
        mk_error "mk_generate_metafile: requires a METAFILE"
        return 1
    fi
	exec 6>"${METAFILE}"
	mk_comment "`hostname` @ `date`"
	result="${METAFILE}"	
	mk_pop_vars
	return 0
}

mk_generate_metafile()
{
	mk_push_vars \
		METAFILE FILE \
		FILE FILE_SIZE FILE_UID FILE_GID FILE_USER \
		FILE_GROUP FILE_MODE FILE_MTIME FILE_SHA1 IPFILE IPFILE_SHA1 \
		_var _file _metafile _file_hash _ipfile_hash _shortfile
	mk_parse_params
	if [ -z "${METAFILE}" ]
	then
		mk_error "mk_generate_metafile: requires a METAFILE"
		return 1
	fi
	if [ -z "${FILE}" ]
	then
		mk_error "mk_generate_metafile: requires a FILE"
		return 1
	fi
	exec 6>"${METAFILE}"
	mk_comment "${FILE}"
	mk_run hostname
	hostname="$result"
	mk_emitf "HOSTNAME=%s\n" "${hostname}"
	mk_sha1 "${FILE}"
	_file_hash="$result"
	mk_emitf "FILE_SHA1=%s\n" "${_file_hash}"
	mk_msg "SHA1(${_shortfile})=${_file_hash}"
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
}
