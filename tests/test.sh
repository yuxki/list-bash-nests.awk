#!/bin/sh

AWK=$1
EXPECT=`cat tests/sorted-output.txt`
RESULT=`$AWK -f list-bash-nests.awk tests/input | sort -t, -k 4,4n -k 5,5n `

if [ "$EXPECT" = "$RESULT" ]; then
  exit 0
fi

echo "[ERROR]: Unexpected output is found"
exit 1
