SHELL := /bin/bash

install-dependencies:
	sudo apt update
	sudo apt install python3-pip python3.10-venv -y
	 
start-dev-setup:
	python3 -m venv .venv/
	source .venv/bin/activate && pip install pyspark


.PHONY: install-dependencies
.PHONY: start-dev-setup

