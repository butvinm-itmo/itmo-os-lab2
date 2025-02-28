#!/bin/bash
set -x

if [ -z "$1" ]; then
    echo "Usage: $0 <profile-data-dir> <runners-number> <command>"
    exit 1
fi

PROFILE_DATA_DIR="$1"
shift

RUNNERS_NUMBER="$1"
shift

COMMAND=$@

# rm -rf $PROFILE_DATA_DIR
mkdir -p $PROFILE_DATA_DIR

if [[ $RUNNERS_NUMBER -eq 1 ]]; then
    STRACE="true"
else
    STRACE="false"
fi

for (( RUNNER_NO=1; RUNNER_NO<=RUNNERS_NUMBER; RUNNER_NO++ )); do
    profiling/profile.sh $PROFILE_DATA_DIR $RUNNER_NO $STRACE $COMMAND &
done

wait

RUNNERS_PIDS=""
for (( RUNNER_NO=1; RUNNER_NO<=RUNNERS_NUMBER; RUNNER_NO++ )); do
    $COMMAND &
    RUNNER_PID=$!
    if [ -z "$RUNNERS_PIDS" ]; then
        RUNNERS_PIDS="$RUNNER_PID"
    else
        RUNNERS_PIDS="$RUNNERS_PIDS,$RUNNER_PID"
    fi
done

top -d 1 -n 5 -b -p $RUNNERS_PIDS > "$PROFILE_DATA_DIR/runners.top" &

mpstat -P ALL 1 5 > "$PROFILE_DATA_DIR/runners.mpstat" &

wait
