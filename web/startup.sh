#!/bin/bash

bundle install --without development test
ruby $MAIN_APP_FILE -p 80
