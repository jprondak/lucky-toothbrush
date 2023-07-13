{
	if (NR==1) { next } # ignore header
	if (!$1) { next }
	if (!$2) {
		printf("ERROR: %s has no ipaddress\n", $1) | "cat >&2"
		next 
    }
	if ($2 ~ /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/) {
		n = split($2, a ,".");
        if ( n == 4 ) {
			ip = sprintf("%d.%d.%d.%d", a[1], a[2], a[3], a[4]);
		} else {
			printf("ERROR: %s: %s has a bad ipaddress\n", $1, $2) | "cat >&2"
			next; 
		}
	}
	if (ip == "127.0.0.1" ) {
		printf("ERROR: %s: %s is localhost \?\n", $1, $2) | "cat >&2"
		next; 
	}
	if (ip == "0.0.0.0" ) {
		printf("ERROR: %s: %s is all zeros \?\n", $1, $2) | "cat >&2"
		next; 
	}
    hosts[ip];
#	print ip;
#    print $1, $2
}
END {
	for ( ip in hosts ) { print ip }
}
