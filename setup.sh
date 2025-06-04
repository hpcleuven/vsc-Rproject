#!/bin/bash -l

VERSION=1.0.0

GIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APPDIR="${VSC_DATA}/.local/apps/vsc-Rproject/${VERSION}"
MODDIR="${VSC_DATA}/.local/modules/"

mkdir -p "${APPDIR}"
mkdir -p "${MODDIR}"

cp -R "${GIT_ROOT}/libexec" "${APPDIR}" 
cp -R "${GIT_ROOT}/module_file/vsc-Rproject" "${MODDIR}"

# Making the module available via .bashrc
echo 'execute following line manually to make the module available:'
echo 'export MODULEPATH="${VSC_DATA}/.local/modules:${MODULEPATH}"'

#echo 'export MODULEPATH="${VSC_DATA}/.local/modules:${MODULEPATH}"' >> ~/.bashrc
#source ~/.bashrc
