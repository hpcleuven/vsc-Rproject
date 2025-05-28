#!/bin/bash -l

GIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "${VSC_DATA}/.local/apps/"
cp -R "${GIT_ROOT}/src/vsc-Rproject" "${VSC_DATA}/.local/apps/" 

mkdir -p "${VSC_DATA}/.local/modules"
cp -R "${GIT_ROOT}/module_file/vsc-Rproject" "${VSC_DATA}/.local/modules"

# Making the module available via .bashrc
echo "execute following line manually to make the module available:"
echo 'export MODULEPATH="${VSC_DATA}/.local/modules:${MODULEPATH}"'

#echo 'export MODULEPATH="${VSC_DATA}/.local/modules:${MODULEPATH}"' >> ~/.bashrc
#source ~/.bashrc
