#!/bin/bash
git submodule update --init --recursive
cd bcm-rpi3
git checkout master
git submodule update --init --recursive
cd kernel
git checkout remotes/origin/rpi-4.4.y-re4son
