#!/bin/bash
for emoji in $(cat paras_scripts/emoji.txt); do
    export CFGSCALE="7.5"
    export PROMPT="illustration of the $emoji emoji, trending on artstation, deviantart, PG rating, SFW, $emoji, $emoji, $emoji, $emoji, $emoji, $emoji"
    sbatch paras_scripts/eval.sh
done