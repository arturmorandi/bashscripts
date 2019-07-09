#!/bin/bash
for img in $(find -size -3512c | grep -v .git | grep png); do rm -rf $img; done
