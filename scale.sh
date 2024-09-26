#!/usr/bin/zsh

TEST_RABBIT_USER=hrutvik
TEST_RABBIT_PASS=rabbit
TEST_RABBIT_HOST=localhost
TEST_RABBIT_MANAGEMENTCONSOLE_PORT=15672
TEST_QUEUE_NAME=durable_task_queue

# tresholds for scaling workers
MIN_WORKERS=2
MAX_WORKERS=10
THRESHOLD_UP=50
THRESHOLD_DOWN=15

# file to store worker PIDs
GO_WORKERS_PID_FILE=/home/hrutvik_/pers/rabbit-mq/.worker_pids.txt

# command to start a worker
GO_WORKER_CMD="/home/hrutvik_/pers/rabbit-mq/go-rabbit-mq-producer/go-worker"

# number of current workers
get_worker_count() {
    if [[ -f $GO_WORKERS_PID_FILE ]]; then # the -f flag checks if the file exists
        wc -l < $GO_WORKERS_PID_FILE 
    else
        echo 0
    fi
}

# spawn a new worker and save PID to file
spawn_worker() {
    echo "Spawning new worker"
    eval "$GO_WORKER_CMD &"
    WORKER_PID=$!
    echo $WORKER_PID >> $GO_WORKERS_PID_FILE
    echo "Spawned worker [PID]: $WORKER_PID"
}

# kill a worker and remove PID from file
kill_worker() {
    if [[ -s $GO_WORKERS_PID_FILE ]]; then # the -s flag checks if the file is not empty
        WORKER_PID=$(head -n 1 $GO_WORKERS_PID_FILE)
        echo "Killing worker with [PID]: $WORKER_PID"
        kill $WORKER_PID
        sed -i "/$WORKER_PID/d" $GO_WORKERS_PID_FILE
        echo "Killed worker [PID]: $WORKER_PID"
    else
        echo "No workers to kill"
    fi
}

# depth of my rabbitmq queue
# curl -s -u hrutvik:rabbit http://localhost:15672/api/queues/%2F/hello | jq '.messages' 

# RQ_DEPTH=$(curl -s -u hrutvik:rabbit http://localhost:15672/api/queues/%2F/hello | jq '.messages' )

# echo $RQ_DEPTH
get_queue_depth() {
    curl -s -u $TEST_RABBIT_USER:$TEST_RABBIT_PASS http://$TEST_RABBIT_HOST:$TEST_RABBIT_MANAGEMENTCONSOLE_PORT/api/queues/%2F/$TEST_QUEUE_NAME | jq '.messages'
}

# TODO: move this into main loop
# spawn at least one worker
if [[ $(get_worker_count) -lt 1 ]]; then
    echo "No workers found, spawning one"
    spawn_worker
fi

# main loop to scale workers
while true; do
    WORKER_COUNT=$(get_worker_count)
    QUEUE_DEPTH=$(get_queue_depth)
    # print time
    echo $(date)
    echo "Current worker count: $WORKER_COUNT"
    echo "Current queue depth: $QUEUE_DEPTH"

    if [[ $QUEUE_DEPTH -gt $THRESHOLD_UP ]]; then
        if [[ $WORKER_COUNT -lt $MAX_WORKERS ]]; then
            spawn_worker
        else
            echo "Max workers reached"
        fi
    elif [[ $QUEUE_DEPTH -lt $THRESHOLD_DOWN ]]; then
        if [[ $WORKER_COUNT -gt $MIN_WORKERS ]]; then
            kill_worker
        else
            echo "Min workers present"
        fi
    fi

    sleep 20
done
