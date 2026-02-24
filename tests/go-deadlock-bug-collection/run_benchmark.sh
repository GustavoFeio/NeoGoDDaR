#!/bin/bash

CORRECT_USAGE="Usage: $0 [-h|--help] [-v|--verbose] [-t|--terminal] [-c|--clean]"

while [ $# -ge 1 ]; do
	case $1 in
		-t|--terminal) terminal=true; shift ;;
		-v|--verbose) verbose="-v"; shift ;;
		-c|--clean) rm -frv $(find . -type f -name "*.output"); exit 0 ;;
		-h|--help) echo $CORRECT_USAGE; exit 0 ;;
		*) echo "Unknown option '$1'."; echo $CORRECT_USAGE; exit 1 ;;
	esac
done

if [ $# -ne 0 ]; then
	echo "Invalid number of arguments."
	echo $CORRECT_USAGE
	exit 1
fi

echo "Building program..."
dune build --no-print-directory ..
if [ $? -ne 0 ]; then
	exit 1
fi
echo "Program built successfully."

root_dir=$(pwd)

total_tests=0
passed_tests=0

# moby#21233 enters an infinite loop, therefore we skip it
dirs=$(find . -maxdepth 1 -type d -not -name ".*" -and -not -name "*moby_21233*")
for f in $(find $dirs -type f -name "*.migo")
do
	cd $(dirname $f)
	echo ""
	FILE=$(basename $f)
	OUTPUT_FILE="$FILE.output"

	echo -n "Checking $f: "

	if [ "$terminal" = true ]; then
		dune exec --no-print-directory GoDDaR -- $verbose migo $FILE
	else
		dune exec --no-print-directory GoDDaR -- $verbose migo $FILE > $OUTPUT_FILE 2>&1
	fi

	exit_status=$?
	if [ $exit_status -eq 0 ]; then
		echo "SUCCESS."
		passed_tests=$((passed_tests+1))
	else
		echo "FAILURE."
	fi
	if [ "$terminal" != true ] && [ $exit_status -ne 0 ] || [ "$verbose" = true ]; then
		cat $OUTPUT_FILE
	fi
	total_tests=$((total_tests+1))

	echo ""
	cd $root_dir
done

echo "Results: $passed_tests/$total_tests tests passed"

