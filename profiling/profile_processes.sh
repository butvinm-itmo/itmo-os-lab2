#!/bin/bash
set -xe

if [ -z "$1" ]; then
    echo "Usage: $0 <profile-data-dir> <processes> <command>"
    exit 1
fi

PROFILE_DATA_DIR="$1"
shift

PROCESSES="$1"
shift

COMMAND=$@

mkdir -p $PROFILE_DATA_DIR

# strace has a significant resources overhead, so we do not want to always run it
# single process result is relevant anyway
if [[ $PROCESSES -eq 1 ]]; then
    STRACE="true"
else
    STRACE="false"
fi

for (( PROCESS_NO=1; PROCESS_NO<=PROCESSES; PROCESS_NO++ )); do
    profiling/profile.sh $PROFILE_DATA_DIR $PROCESS_NO $STRACE $COMMAND &
done

wait

PIDS=""
for (( PROCESS_NO=1; PROCESS_NO<=PROCESSES; PROCESS_NO++ )); do
    $COMMAND &
    PID=$!
    if [ -z "$PIDS" ]; then
        PIDS="$PID"
    else
        PIDS="$PIDS,$PID"
    fi
done

top -d 1 -n 5 -b -p $PIDS > "$PROFILE_DATA_DIR/all.top" &

mpstat -P ALL 1 5 > "$PROFILE_DATA_DIR/all.mpstat" &

wait
