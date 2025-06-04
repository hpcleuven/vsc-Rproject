help([[
vsc-Rproject/1.0.0 is a command-line tool that facilitates the creation and usage of
RStudio Project-based R environments on top of the existing module system.
]])

whatis("Name: vsc-Rproject")
whatis("Version: 1.0.0")
whatis("Category: tools")

-- module load and unload hooks
execute{cmd="source " .. "${VSC_DATA}/.local/apps/vsc-Rproject/1.0.0/load.sh", modeA={"load"}}
execute{cmd="source " .. "${VSC_DATA}/.local/apps/vsc-Rproject/1.0.0/unload.sh", modeA={"unload"}}
