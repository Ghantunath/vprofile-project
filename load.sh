#!/bin/bash

while true; do
    # Randomly decide how intense the stress should be (1–3 workers)
    cpu_workers=$(( (RANDOM % 3) + 1 ))

    # Random stress duration: 20–60 seconds
    duration=$(( (RANDOM % 40) + 20 ))

    echo "🔥 Stressing: $cpu_workers CPU(s) for $duration seconds"
    stress --cpu $cpu_workers --vm 1 --vm-bytes 70M --io 1 --timeout ${duration}s >/dev/null 2>&1

    # Random cooldown period: 10–40 seconds
    cooldown=$(( (RANDOM % 30) + 10 ))
    echo "💤 Cooling down for $cooldown seconds"
    sleep $cooldown
done

