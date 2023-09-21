#!/bin/bash

baseName=$(basename "$(pwd)")
newBaseName=$(basename "$(pwd)")
episode="$baseName.m4a"
counter=1
latestCounter=1

while [ -e "$episode" ]; do
    episode="$baseName-$counter.m4a"
    latestCounter=$counter
    ((counter++))
done

cp "$baseName.md" "$baseName-$latestCounter.md"
cp "$baseName.txt" "$latestCounter.txt"
cp "$baseName.png" "$latestCounter.png"

