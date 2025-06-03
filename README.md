![vsc-Rproject](assets/vsc_rproject.png)

# vsc-Rproject

vsc-Rproject is a command-line tool that facilitates the creation and use of
RStudio Project-based R environments on top of the existing module system.

## Setup

Clone the repository to your `$VSC_DATA` directory. 

```bash
git clone git@github.com:hpcleuven/vsc-Rproject.git $VSC_DATA
cd $VSC_DATA/vsc-Rproject
```

Next, you can install this tool locally in your $VSC_DATA directory, using the `setup.sh` script. 
This script:
 - places the `load.sh` and `unload.sh` scripts in `$VSC_DATA/.local/apps/vsc-Rproject/1.0/libexec/`.
 - places the `module_file/vsc-Rproject/1.0.lua` module file in `$VSC_DATA/.local/modules/vsc-Rproject/`

```bash
bash setup.sh
```

After the setup is complete, you will still need to extend your module path.

```bash
export MODULEPATH="${VSC_DATA}/.local/modules:${MODULEPATH}"`
```

Optionally run the following commands to extend your module path from your bashrc file.

```bash
echo 'export MODULEPATH="${VSC_DATA}/.local/modules:${MODULEPATH}"' >> ~/.bashrc
source ~/.bashrc
```

## Testing vsc-Rproject

After installing vsc-Rproject with `setup.sh` you run the `test_vsc_rproject.sh` script:

```bash
cd testing
bash test_vsc_rproject.sh
```

You can always extend this script by adding your own test cases. 

## Using vsc-Rproject

Load the `vsc-Rproject/1.0` module

```bash
module load vsc-Rproject/1.0
```
Now you can call `vsc-rproject` and use the subcommands: `create`, `activate`, `deactivate` and `configure`.

e.g.
```bash
vsc-rproject --help
vsc-rproject create --help
vsc-rproject create --modules="modules.txt" --activate
```

To use `vsc-rproject` within the context of a bash script, the `vsc-Rproject` module has to be loaded inside the script.

In order to further support a heterogeneous environment the `$VSC_RPROJECT_CONFIG` environment variable can be used to specify an alternative `.vsc-rproject-config` file. This allows for easy switching between different configurations depending on the needs of the user. e.g. working on different clusters.
If `$VSC_RPROJECT_CONFIG` is set, `vsc-rproject` will consider it and use it if possible. 
If `$VSC_RPROJECT_CONFIG` is not set (default) `vsc-rproject` will use check the default config file: `~/.vsc-rproject-config`.

> **Note:** `vsc-rproject configure` cannot be used to change the settings for existing projects. If you wish to change the settings of an existing projects, you need manually update the relevant files. e.g. `$VSC_RPROJECT/.R/makevars`.

> **Note:** 
The `-march=x86-64-v4` flag is used as the default for microarchitecture optimization targeting Intel Skylake and newer processors. However, this flag is only supported in GCC version 12 and later. If you are using an older version of `R` that relies on an earlier GCC version, `-march=x86-64-v4` may not be recognized. In such cases, you can run `gcc --target-help` to view the list of supported `-march` values and choose a more appropriate setting.

