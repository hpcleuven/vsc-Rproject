#!/bin/bash
#
# Author: Wouter Van Assche
#
# This script unsets all functions previously loaded by load.sh 
#
###############################################################################

complete -r vsc_rproject

unset VSC_RPROJECT_VERSION
unset __vscrproject__default_r

unset -f vsc_rproject
unset -f __vscrproject__completions
