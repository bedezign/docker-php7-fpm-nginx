# !/usr/bin/env bash
set -x 
docker pull php:7.2-fpm
docker build $* -t bedezign/php:7.2-fpm-nginx .
