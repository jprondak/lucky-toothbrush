#
# module/date.sh
#
# Date conversion routines
#
#!/bin/ksh -p

# return the number of days in a year
# usage yeardays yyyy
mk_yeardays () {
	y=
	if [ X$1 = X ]
	then
		read y
	else
		y=$1
	fi

	# a year is a leap year if it is even divisible by 4
	# but not evenly divisible by 100
	# unless it is evenly divisible by 400

	# if it is evenly divisible by 400 it must be a leap year
	a=$(( $y % 400 ))
	if [ $a = 0 ]
	then
		echo 366
		return
	fi

	#if it is evenly divisible by 100 it must not be a leap year
	a=$(( $y % 100 ))
	if [ $a = 0 ]
	then
		echo 365
		return
	fi
	
	# if it is evenly divisible by 4 it must be a leap year
	a=$(( $y % 4 ))
	if [ $a = 0 ]
	then
		echo 366
		return
	fi

	echo 365
}

mk_monthdays ()
{
	ymd=
	if [ X$1 = X ]
	then
		read ymd
	elsif [ X$2 = X ]
		ymd=$1
	else
		ymd=$(( ( $1 * 10000 ) + ( $2 * 100 ) + 1 ))
	fi

	y=$(( $ymd / 10000 ))
	m=$(( ( $ymd % 10000 ) / 100))

	case $m in
	1|3|5|7|8|10|12) echo 31; return;;
	4|6|9|11)	 echo 30; return;;
	*) ;;
	esac

	diy=`mk_yeardays $y`

	case $diy in
	365) echo 28; return;;
	366) echo 29; return;;
	esac
}

# ymd2yd converts yyyymmdd to yyyyddd
# usage ymd2yd 19980429
mk_ymd2yd ()
{
	if [ X$1 = X ]
	then
		read  dt
	else
		dt=$1
	fi

	# break the yyyymmdd into separate parts for year, month, and day

	y=$(( $dt / 10000 ))
	m=$(( ( $dt % 10000 ) / 100 ))
	d=$(( $dt % 100 ))

	# add the days in each month, up to but not including the month
	# itself, into the days. For example, if the date is 19980203,
	# extract the number of days in January and add it to 03.
	# If the date is June 14, 1998, extract the number of days in
	# January, February, March, April, and May and add them to 14.

	x=1
	while [ $(( $x < $m )) = 1 ]
	do
		md=`mk_monthdays $y $x`
		d=$(( $d + $md ))
		x=$(( $x + 1 ))
	done

	# combine the year and day back together again and you have the 
	# julian date.

	jul=$(( ( $y * 1000 ) + $d ))
	echo $jul
}

# converts yyyyddd to yyyymmdd
# usage yd2ymd 1998213
mk_yd2ymd () 
{
	if [ X$1 = X ]
	then
		read dt
	else
		dt=$1
	fi

	y=$(( $dt / 1000 ))
	d=$(( $dt % 1000 ))

	# subtract the number of days in each month starting from 1
	# from the days in the date. When the day goes below 1, you
	# have the current month. Add back the number of days in the
	# month to get the correct day of the month
	m=1
	while [ $(( $d > 0 )) = 1 ]
	do
		md=`mk_monthdays $y $m`
		d=$(( $d - $md ))
		m=$(( $m + 1 ))
	done

	d=$(( $d + $md ))

	# the loop steps one past the correct month, so back up the month
	m=$(( $m - 1 ))

	# assemble the results into a gregorian date
	grg=$(( ( $y * 10000 ) + ( $m * 100 ) + $d ))
	echo $grg
}

mk_diffdays ()
{
	if [ X$2 = X ]
	then
		dif=$1
		read yd
	else
		yd=$1
		dif=$2
	fi

	# Break it into pieces
	d=`expr $yd % 1000`
	y=`expr $yd / 1000`

	# Add the number of days (if days is negative this results in
	# a subtraction)
	d=`expr $d \+ $dif`

	# Extract the days in the year
	diy=`yeardays $y`

	# If the calculated day exceeds the days in the year, 
	# add one year to the year and subtract the days in the year from the
	# calculated days. Extract the days in the new year and repeat
	# test until you end up with a day number that falls within the
	# days of the year
	while [ `expr $d \> $diy` = 1 ]
	do
		d=`expr $d - $diy`
		y=`expr $y \+ 1`
		diy=`yeardays $y`
	done
	
	# This is the reverse process. If the calculated number of days
	# is less than 1, move back one year. Extract
	# the days in this year and add the days in the year
	# loop on this test until you end up with a number that
	# falls within the days of the year
	while [ `expr $d \< 1` = 1 ]
	do
		y=`expr $y - 1`
		diy=`yeardays $y`
		d=`expr $d \+ $diy`
	done
	
	# put the year and day back together and echo the result
	
	yd=`expr \( $y \* 1000 \) + $d`
	
	echo $yd
}

#mk_julian_delta ()
#{
#	mk_push_vars
#	result=
#	
#	if [ X$2 = X ]
#	then
#		dif=$1
#		read yd
#	else
#		yd=$1
#		dif=$2
#	fi
#
#	# Break it into pieces
#	y1=$(( $date1 / 1000 ))
#	d1=$(( $date1 % 1000 ))
#
#	y2=$(( $date2 / 1000 ))
#	d2=$(( $date2 % 1000 ))
#	diy=$(( $y1 - $y2 ))
#	
#	while
#	diy1=`yeardays $y1`
#	diy2=`yeardays $y1`
#	# Add the number of days (if days is negative this results in
#	# a subtraction)
#	d=`expr $d \+ $dif`
#
#	# Extract the days in the year
#
#	# If the calculated day exceeds the days in the year, 
#	# add one year to the year and subtract the days in the year from the
#	# calculated days. Extract the days in the new year and repeat
#	# test until you end up with a day number that falls within the
#	# days of the year
#	while [ `expr $d \> $diy` = 1 ]
#	do
#		d=`expr $d - $diy`
#		y=`expr $y \+ 1`
#		diy=`yeardays $y`
#	done
#	
#	# This is the reverse process. If the calculated number of days
#	# is less than 1, move back one year. Extract
#	# the days in this year and add the days in the year
#	# loop on this test until you end up with a number that
#	# falls within the days of the year
#	while [ `expr $d \< 1` = 1 ]
#	do
#		y=`expr $y - 1`
#		diy=`yeardays $y`
#		d=`expr $d \+ $diy`
#	done
#	
#	# put the year and day back together and echo the result
#	
#	yd=`expr \( $y \* 1000 \) + $d`
#	
#	echo $yd
#}
mk_date_to_julian ()
{
	YEAR=
	MONTH=
	DAY=

	if [ $# = 1 ]
	then
		YEAR=$(( $1 / 10000 ))
		MONTH=$(( ( $1 % 10000 ) / 100 ))
		DAY=$(( $1 % 100 ))
	else
		
		YEAR=$1
		MONTH=$2
		DAY=$3
	fi	
	result=$(( $DAY - 32075 + 1461 * \
		( $YEAR + 4800 + ( $MONTH - 14 ) / 12 ) / 4 + \
		367 * ( $MONTH - 2 - ( $MONTH - 14 ) / 12 * 12 ) / \
		12 - 3 * (( $YEAR + 4900 + ( $MONTH - 14 ) / 12 ) / 100 ) / 4))
#	printf "%d" $result
}

mk_julian_to_date ()
{
	JD=$1
	L=$(( $JD + 68569 ))
	N=$(( 4 * $L / 146097 ))
	L=$(( $L - ( 146097 * $N + 3 ) / 4 ))
	I=$(( 4000 * ( $L + 1 ) / 1461001 ))
	L=$(( $L - 1461 * $I / 4 + 31 ))
	J=$(( 80 * $L / 2447 ))
	K=$(( $L - 2447 * $J / 80 ))
	L=$(( $J / 11 ))
	J=$(( $J + 2 - 12 * $L ))
	I=$(( 100 * ( $N - 49 ) + $I + $L ))
	YEAR=`printf "%04d" ${I}`
	MONTH=`printf "%02d" ${J}`
	DAY=`printf "%02d" ${K}`
	result=`printf "%04d%02d%02d" ${I} ${J} ${K}`
}
