#
#
#
VERSION="${VERSION:-1}"
PROGNAME="${PROGNAME:-`echo $0 | sed -e 's!.*/!!'`}"
PROGDIR="${PROGDIR:-`echo $0 | sed -e 's!/.*$!!'`}"
PROGDIR=`dirname $0`
BASEDIR="${BASEDIR:-`(cd $PROGDIR; pwd)`}"
SELF="${SELF:-`cd $BASEDIR; pwd`/$PROGNAME}"
MK_SYSTEM=host
MK_QUIET=1
PARENT="`dirname ${MK_COMMAND_PATH}`"
PARENT="`(cd $PARENT; cd ..; pwd)`"

export PROGNAME BASEDIR SELF PARENT

. "${MK_HOME}/mk/mk.sh" || exit 1
. "${MK_HOME}/mk/module/core.sh" || exit 1
. "${MK_HOME}/mk/module/program.sh" || exit 1

. "${MK_HOME}/module/logging.sh" || exit 1
. "${MK_HOME}/module/common.sh" || exit 1
. "${MK_HOME}/module/date.sh" || exit 1
. "${MK_HOME}/module/ini.sh" || exit 1
. "${MK_HOME}/module/segway.sh" || exit 1

prefix=$PARENT
exec_prefix=${prefix}
mandir=${prefix}/man
libdir=${prefix}/lib
sbindir=${prefix}/sbin
bindir=${prefix}/bin
datadir=${prefix}/share
sysconfdir="${sysconfdir:-${prefix}/etc}"
llibdir=${prefix}/llib
lbindir=${prefix}/lbin
lsbindir=${prefix}/lsbin
localstatedir="${localstatedir:-/var/tmp/lucky-toothbrush}"
metadir="${metadir:-${localstatedir}/meta}"
logdir="${localstatedir}/log"
archivedir="${LT_ARCHIVEDIR:-/data01/SOC_LOG_ARCHIVE}"
metadir="${LT_METADIR:-${metadir}}"
startdate="${LT_STARTDATE:-`date '+%Y%m%d'`}"
enddate="${LT_ENDDATE:-`date '+%Y%m%d'`}"
buckets="${LT_BUCKETS:-}"
: ${verbose:=0}

PATH=/bin:/usr/bin:/sbin:/usr/sbin

case `uname | tr '[:upper:]' '[:lower:]'` in
	sunos)
		PERL=/usr/perl5
		OS=solaris
		;;
	linux)
		OS=linux
		;;
	darwin)
		OS=osx
		PATH=$PATH:/usr/ucb:/usr/etc
		;;
	*)
		;;
esac

if [ -n "$PERL" ]
then
	PATH=${PERL}/bin:$PATH
fi

PATH=./bin:./sbin:$PATH

# If the system has /usr/xpg4/bin, add it to the path
# so we get POSIX-compliant utilities
if test -d "/usr/xpg4/bin"
then
	PATH="/usr/xpg4/bin:$PATH"
fi

PATH=$MK_COMMAND_PATH:$PATH

export PATH

mk_check_program VAR=P_POD2USAGE FAIL=no QUIET=$O_QUIET pod2usage
mk_check_program VAR=P_PERL FAIL=yes QUIET=$O_QUIET perl
mk_check_program VAR=P_FIND FAIL=yes QUIET=$O_QUIET find
mk_check_program VAR=P_OPENSSL FAIL=yes QUIET=$O_QUIET openssl
mk_check_program VAR=P_GZIP FAIL=yes QUIET=$O_QUIET gzip
mk_check_program VAR=P_PICKER FAIL=yes QUIET=$O_QUIET date-picker
mk_check_program VAR=P_EXTRACTIPS FAIL=yes QUIET=$O_QUIET extract-ips
mk_check_program VAR=P_NORMALIZEIPS FAIL=yes QUIET=$O_QUIET normalize-ips
mk_check_program VAR=P_DEDUPIPS FAIL=yes QUIET=$O_QUIET dedup-ips
mk_check_program VAR=P_BADIPS FAIL=yes QUIET=$O_QUIET bad-ips
mk_check_program VAR=P_RESOLVEIPS FAIL=yes QUIET=$O_QUIET resolve-ips
mk_check_program VAR=P_DUMPCSVIPS FAIL=yes QUIET=$O_QUIET dump-csv-ips
mk_check_program VAR=P_FOUNDIPS FAIL=yes QUIET=$O_QUIET found-ips
mk_check_program VAR=P_MISSINGIPS FAIL=yes QUIET=$O_QUIET missing-ips
mk_check_program VAR=P_ZIP FAIL=yes QUIET=$O_QUIET zip

HOSTNAME=`hostname`
FQDN=`get_myfqdn`

