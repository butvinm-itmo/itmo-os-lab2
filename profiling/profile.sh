#!/bin/bash
set -xe

if [ -z "$1" ]; then
    echo "Usage: $0 <profile-data-dir> <process-no> <run-strace> <command>"
    exit 1
fi

PROFILE_DATA_DIR="$1"
shift

PROCESS_NO="$1"
shift

RUN_STRACE="$1"
shift

COMMAND=$@

mkdir -p $PROFILE_DATA_DIR

if [[ "$RUN_STRACE" == "true" ]]; then
    strace -c -o "$PROFILE_DATA_DIR/$PROCESS_NO.strace" $COMMAND
fi

ltrace -c -o "$PROFILE_DATA_DIR/$PROCESS_NO.ltrace" $COMMAND

$COMMAND & PID=$! && perf record -F 99 -g -o "$PROFILE_DATA_DIR/$PROCESS_NO.perf" --pid $PID

perf script -i "$PROFILE_DATA_DIR/$PROCESS_NO.perf" | ./FlameGraph/stackcollapse-perf.pl --inline --all | ./FlameGraph/flamegraph.pl > "$PROFILE_DATA_DIR/FlameGraph-$PROCESS_NO.svg"

$COMMAND & PID=$! && perf stat -e task-clock,context-switches,cache-misses,cache-references,instructions,cycles -o "$PROFILE_DATA_DIR/$PROCESS_NO.stat" --pid $PID

$COMMAND & PID=$! && pidstat -p $PID 1 >> "$PROFILE_DATA_DIR/$PROCESS_NO.pidstat"
