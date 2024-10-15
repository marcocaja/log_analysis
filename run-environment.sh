#!/bin/bash

sudo apt update && sudo apt install python3-pip python3.10-venv -y

python3 -m venv .venv/;

source .venv/bin/activate;

pip install ipython pyspark;

