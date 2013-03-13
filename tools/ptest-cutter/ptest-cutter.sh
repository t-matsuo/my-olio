#!/bin/bash
#
# Description : get ptest results and cut unnecessary strings
#               to compare
#
#   Authors  : Takatoshi MATSUO (matsuo.tak@gmail.com)
#   Copyright: Takatoshi MTTSUO (matsuo.tak@gmail.com)
#
# usage : ./ptest-cutter.sh [bzip-direcotry] [noptest]

PTESTDIR=ptest-result
CUTDIR=ptest-cut
SKIP="false"

if [ "$1" = "" ]; then
    echo "usage : ./ptest-cutter.sh [bzip2 directory]"
    exit 1
fi

if [ "$2" = "noptest" ]; then
    echo "skip ptest"
    SKIP="true"
fi

if [ ! -d $1 ]; then
    echo "\"$1\" directory not found"
    exit 1
fi
BZ2DIR=$1

# check binary
which ptest > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ptest command not found"
    exit 1
fi

# check version
VERSION=`ptest --version | head -1 | tr -s " " | cut -d " " -f 2`
echo $VERSION | grep -q [^0-9.-]
if [ $? -eq 0 ]; then
    echo "version [$VERSION] is invalid"
    exit 1
fi

echo "ptest version is $VERSION"

# make directory
if [ ! -d $VERSION ]; then
    mkdir $VERSION
fi
if [ ! -d $VERSION/$PTESTDIR ]; then
    mkdir $VERSION/$PTESTDIR
fi
if [ ! -d $VERSION/$CUTDIR ]; then
    mkdir $VERSION/$CUTDIR
fi

# cleanup
if [ "$SKIP" = "false" ]; then
    rm -f $VERSION/$PTESTDIR/*.log
fi
rm -f $VERSION/$CUTDIR/*.log

### main #############################################
# output result of ptest
if [ "$SKIP" = "false" ]; then
    for bz2file in `ls $BZ2DIR/*bz2`
    do
        input_file=`basename $bz2file`
        output_file=`echo "$input_file" | sed -e "s/bz2$/log/g"`
        echo "Making log file of $input_file"
        bunzip2 -c $BZ2DIR/$input_file | ptest -VVV -s -x - > $VERSION/$PTESTDIR/$output_file 2>&1
    done
fi

# remove pid of ptest and date strings.
for logfile in `ls $VERSION/$PTESTDIR`
do
    echo "Cutting $logfile"
    cat $VERSION/$PTESTDIR/$logfile | \
    sed -e "s/^ptest\[[0-9]*\]: [0-9][0-9][0-9][0-9]\/[0-9][0-9]\/[0-9][0-9]_[0-9][0-9]:[0-9][0-9]:[0-9][0-9] //g" |\
    grep -e "^notice:"  \
    > $VERSION/$CUTDIR/$logfile
done

echo done
echo
echo "Let's compare \"$VERSION/$CUTDIR\" directory to another version's directory"
echo
exit 0

