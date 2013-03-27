#!/bin/bash
#
# Description : get ptest results and cut unnecessary strings
#               to compare
#
#   Authors  : Takatoshi MATSUO (matsuo.tak@gmail.com)
#   Copyright: Takatoshi MTTSUO (matsuo.tak@gmail.com)

: ${PTEST:=$(which ptest 2>/dev/null)}
PTESTDIR=ptest-result
CUTDIR=ptest-cut
SKIP_PTEST="false"

usage() {
cat << END

Usage : ptest-cutter.sh [-c] {-b} directory

      OPTIONS
      -b directory     specify the directory including bz2 files
      -c               cut only (not execute ptest)

END
    exit 1
}

while getopts "b:c" opts; do
    case $opts in
    b)
        BZ2DIR=$OPTARG
        ;;
    c)
        SKIP_PTEST="true"
        ;;
    esac
done

if [ ! -n "$BZ2DIR" ]; then
    echo "directory not found"
    usage
fi

# check binary
if [ -z "$PTEST" -o ! -x "$PTEST" ]; then
    echo "ptest command not found: $PTEST"
    exit 1
fi

# check version
VERSION=`$PTEST --version | head -1 | tr -s " " | cut -d " " -f 2`
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
if [ "$SKIP_PTEST" = "false" ]; then
    rm -f $VERSION/$PTESTDIR/*.log
fi
rm -f $VERSION/$CUTDIR/*.log

### main #############################################
# output result of ptest
if [ "$SKIP_PTEST" = "false" ]; then
    for bz2file in `ls $BZ2DIR/*bz2`
    do
        input_file=`basename $bz2file`
        output_file=`echo "$input_file" | sed -e "s/bz2$/log/g"`
        echo "Making log file of $input_file"
        bunzip2 -c $BZ2DIR/$input_file | $PTEST -VVV -s -x - > $VERSION/$PTESTDIR/$output_file 2>&1
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

