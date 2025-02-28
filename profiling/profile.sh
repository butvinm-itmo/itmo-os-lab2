#!/bin/bash
set -x

if [ -z "$1" ]; then
    echo "Usage: $0 <profile-data-dir> <runner-no> <command> <strace>"
    exit 1
fi

PROFILE_DATA_DIR="$1"
shift

RUNNER_NO="$1"
shift

STRACE="$1"
shift

COMMAND=$@

if [[ "$STRACE" == "true" ]]; then
    strace -c -o "$PROFILE_DATA_DIR/$RUNNER_NO.strace" $COMMAND
fi

ltrace -c -o "$PROFILE_DATA_DIR/$RUNNER_NO.ltrace" $COMMAND

$COMMAND & RUNNER_PID=$! && perf record -F 99 -g -o "$PROFILE_DATA_DIR/$RUNNER_NO.perf" --pid $RUNNER_PID

perf script -i "$PROFILE_DATA_DIR/$RUNNER_NO.perf" | ./FlameGraph/stackcollapse-perf.pl --inline --all | ./FlameGraph/flamegraph.pl > "$PROFILE_DATA_DIR/FlameGraph-$RUNNER_NO.svg"

$COMMAND & RUNNER_PID=$! && perf stat -d -e task-clock,context-switches,cache-misses,cache-references,instructions,cycles -o "$PROFILE_DATA_DIR/$RUNNER_NO.stat" --pid $RUNNER_PID

$COMMAND & RUNNER_PID=$! && pidstat -p $RUNNER_PID 1 >> "$PROFILE_DATA_DIR/$RUNNER_NO.pidstat"
