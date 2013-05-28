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
DOTDIR=ptest-dot
GRAPHDIR=graph

# default
SKIP_PTEST="false"
CREATE_DOT="false"
CREATE_GRAPH="false"

usage() {
cat << END

usage : pe-tester.sh [-c] [-d] [-g] {-b} directory

      OPTIONS
      -b directory     specify the directory including bz2 files
      -c               not execute ptest
      -d               create dot files using ptest
      -g               create graph(png) files from dot files. need dot command

END
    exit 1
}

while getopts "b:cdg" opts; do
    case $opts in
    b)
        BZ2DIR=$OPTARG
        echo "bz2 directory is $BZ2DIR"
        ;;
    c)
        SKIP_PTEST="true"
        echo "Not execute ptest : $SKIP_PTEST"
        ;;
    d)
        CREATE_DOT="true"
        echo "Create dot files : $CREATE_DOT"
        ;;
    g)
        which dot > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "dot command not found. graphviz package installed ?"
            usage
            exit 1
        fi
        CREATE_GRAPH="true"
        echo "Create graph files : $CREATE_GRAPH"
        ;;
    :|\?)
        usage
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
echo

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
if [ $CREATE_DOT = "true" -a ! -d $VERSION/$DOTDIR ]; then
    mkdir $VERSION/$DOTDIR
fi
if [ $CREATE_GRAPH = "true" -a ! -d $VERSION/$GRAPHDIR ]; then
    mkdir $VERSION/$GRAPHDIR
fi

# cleanup
if [ "$SKIP_PTEST" = "false" ]; then
    rm -f $VERSION/$PTESTDIR/*.log
fi
rm -f $VERSION/$CUTDIR/*.log
if [ $CREATE_DOT = "true" ]; then
    rm -f $VERSION/$DOTDIR/*.dot
fi
if [ $CREATE_GRAPH = "true" ]; then
    rm -f $VERSION/$GRAPHDIR/*.png
fi

### main #############################################
# output result of ptest
if [ "$SKIP_PTEST" = "false" ]; then
    for bz2file in `ls $BZ2DIR/*bz2`
    do
        input_file=`basename $bz2file`
        output_file=`echo "$input_file" | sed -e "s/bz2$/log/g"`
        echo "Making log file of $input_file"
        bunzip2 -c $BZ2DIR/$input_file | $PTEST -VVV -s -x - > $VERSION/$PTESTDIR/$output_file 2>&1
        if [ $CREATE_DOT = "true" ]; then
            output_dotfile=`echo "$input_file" | sed -e "s/bz2$/dot/g"`
            echo "Making dot file of $input_file"
            bunzip2 -c $BZ2DIR/$input_file | $PTEST -D $VERSION/$DOTDIR/$output_dotfile -x - 2>&1
        fi
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

# create graph files
if [ "$CREATE_GRAPH" = "true" ]; then
    for dotfile in `ls $VERSION/$DOTDIR`
    do
        echo "Creating graph file from $dotfile"
        graphfile=`echo $dotfile | sed -e "s/dot$/png/g"`
        dot -Tpng $VERSION/$DOTDIR/$dotfile -o $VERSION/$GRAPHDIR/$graphfile
    done
fi

echo done
echo
echo "Let's compare \"$VERSION/$CUTDIR\" directory to another version's directory"
echo
exit 0

