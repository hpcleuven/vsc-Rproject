#!/bin/bash
#
# Author: Wouter Van Assche
#
# This script facilitates the setup of R project environments that are
# compatible with our HPC infrastructure.
#
# Built with:
#   - bash  4.4.20
#   - lmod  8.7.55-1.el8.x86_64
#   - git   2.39.3
#
###############################################################################

# ================ #
# Global Variables #
# ================ #

VSC_RPROJECT_VERSION="1.0.0"
__vscrproject__default_r=$(module --redirect --default --terse avail | grep -E '^R/')


# ================ #
# vsc Rproject CLI #
# ================ #

# enable autocompletions
__vscrproject__completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local subcommands="Create create Configure configure Activate activate Deactivate deactivate"
  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "${subcommands}" -- "$cur") )
  fi
}
complete -F __vscrproject__completions vsc-rproject


# main entrypoint
vsc-rproject() {

  # ============ #
  # Text Make-Up #
  # ============ #

  local RESET='\033[0m'
  local RED='\033[0;31m'
  local YELLOW='\033[0;33m'
  local GREEN='\033[0;32m'
  local BLUE='\033[0;34m'

  local BRIGHT_GREEN='\033[1;32m'
  local BRIGHT_BLUE='\033[1;34m'

  
  # ================ #
  # Helper Functions #
  # ================ #

  is_quiet(){
    [[ "$quiet" == "true" ]]
  }

  echo_info() {
    is_quiet || echo -e "${GREEN}[INFO] $1${RESET}"
  }

  echo_warning() {
    is_quiet || echo -e "${YELLOW}[WARNING] $1${RESET}"
  }

  echo_error() {
    echo -e "${RED}[ERROR] $1${RESET}"
  }

  echo_cmd() {
    echo -e "${BLUE}[>CMD] $ ${BRIGHT_BLUE}$1${RESET}"
  }

  usage() {
    cat <<-EOF

	vsc-Rproject is a command-line tool that facilitates the creation and use of
	RStudio Project-based R environments on top of the existing module system.

	Usage: vsc-rproject COMMAND [OPTIONS]

	Commands:
	  create            Create a new vsc-Rproject environment.
	  activate          Activate an existing vsc-Rproject environment.
	  deactivate        Deactivate the current vsc-Rproject environment.
	  configure         Configure default settings for vsc-Rprojects.

	Options:
	  -d | --defaults   show default settings
	  -h | --help       show this help message
	  -v | --version    show vsc-Rproject version

	For command-specific help, run:
	  vsc-rproject COMMAND --help

EOF
  }

  show_default_settings() {
    cat <<-EOF

	Default settings:
	  - R module                ${default_r_module}
	  - Project location        ${default_project_location}
	  - CRAN mirror             ${default_cran}
	  - Target CPU Architecture ${default_march}

EOF
  }

  load_defaults() {
    local configs="${VSC_RPROJECT_CONFIG:-${VSC_HOME}/.vsc-rproject-config}"

    # --- Default Settings --- #
    local default_r_module=$__vscrproject__default_r
    local default_project_location="$(realpath ${VSC_DATA}/Rprojects)"
    local default_cran="https://cloud.r-project.org"
    local default_march="x86-64-v4"

    if [[ -f "${configs}" ]]; then
      source "${configs}"
    fi

    printf 'default_r_module=%q\n' "${default_r_module}"
    printf 'default_project_location=%q\n' "${default_project_location}"
    printf 'default_cran=%q\n' "${default_cran}"
    printf 'default_march=%q\n' "${default_march}"
  }

  get_nloaded_modules() {
    local loaded_modules=($(echo "$LOADEDMODULES" | tr ':' '\n' | grep -v -E '^(cluster|vsc-Rproject)/')) # Remove cluster and vsc-Rproject modules
    echo "${#loaded_modules[@]}"
  }

  load_modules() {
    local lines
    local module_list="${1}"
    if ! mapfile -t lines < "${module_list}"; then
      echo_error "Could not read modules script '${module_list}'"
      return 1
    fi
    for line in "${lines[@]}"; do
      if [[ -z "$line" ]]; then
        continue
      elif  module load $line; then
        echo_info "  ✔ Module '$line' loaded successfully"
      else
        echo_error "Could not load module '$line'"
        return 1
      fi
    done
  }

  module_purge_vsc_rproject() {
    local vsc_rproject_module=$(echo "${LOADEDMODULES}" | tr ':' '\n' | grep "^vsc-Rproject/")
    module purge >/dev/null 2>&1
    if [ ! -z ${vsc_rproject_module} ]; then
        module load ${vsc_rproject_module}
    fi
  }

  module_exists(){
    local module_name="${1}"
    local modules=()
    mapfile -t modules < <(module --terse --redirect avail "${module_name}" 2>/dev/null)
    for module in "${modules[@]}"; do
      if [[ "${module}" == "${module_name}" ]]; then
        return 0
      fi
    done
    echo_error "${module_name} not found."
    return 1
  }

  check_project_name() {
    local name="${1}"
    if [[ -z ${name} ]]; then
      echo_error "Project name must be provided"
      return 1
    elif ! [[ ${name} =~ ^[a-zA-Z0-9_-]+$ ]]; then
      echo_error "Invalid name '${name}'."
      echo_error "Only these characters are accepted: a-z, A-Z, 0-9, _, and -]"
      return 1
    fi
  }

  check_project_location() {
    local location="${1}"
    if [[ -z ${location} ]]; then
      echo_error "Location not set"
      return 1
    elif ! [[ ${location} =~ ^[a-zA-Z0-9/_\.-]+$ ]]; then
      echo_error "Invalid location: \"${location}\""
      echo_error "Only these characters are accepted: a-z, A-Z, 0-9, /, _, -, and ."
      return 1
    fi
  }

  check_modules_file() {
    local modules_file="${1}"
    if [[ ! -f "$modules_file" ]]; then
      echo_error "Modules file not found."
      return 1
    fi
  }

  is_vsc_rproject() {
    local path="${1}"
    local rproj_file
    if [ -d "${path}" ]; then
      vsc_rproject_dir="${path}/.vsc-rproject"
      rproj_file=$(find "${path}" -maxdepth 1 -name "*.Rproj" | head -n 1)
      if [ -n "${rproj_file}" ] && grep -q "^Version: " "${rproj_file}"; then
        return 0
      fi
    fi
    return 1
  }

  detect() {
    if ! is_vsc_rproject ${VSC_RPROJECT} ; then
      return 1
    fi
  }

  activate() {
    echo_info "Loading modules from '${project_root}/.vsc-rproject/modules.env'"
    if ! load_modules "${project_root}/.vsc-rproject/modules.env"; then # If the modules could not be loaded
      echo_error "Could not load modules from '${project_root}/.vsc-rproject/modules.env'"
      return 1
    fi

    export VSC_RPROJECT=${project_root}
    echo_info "${project_name} activated"
    echo_info "To use this environment, you must go to your vsc-Rproject directory and launch R or call Rscript:"
    echo_cmd "cd \$VSC_RPROJECT"
    echo_cmd "Rscript myscript.R"
  }

  deactivate() {
    local project_name
    if detect; then
      project_name=$(basename "${VSC_RPROJECT}")
      echo_info "Purging currently loaded modules."
      module_purge_vsc_rproject
      unset VSC_RPROJECT
      echo_info "${project_name} has been deactivated."
    else
      return 1
    fi
  }


  # ============ #
  # Sub-Commands #
  # ============ #
  
  subcmd_create() {

    usage_create() {
      cat <<-EOF

	Usage: vsc-rproject create [PROJECT_NAME] [OPTIONS]

	Options:
	  -n | --name       project name
	  -m | --modules    modules.txt file                    default: ${default_r_module}
	  -l | --location   project location                    default: ${default_project_location}
	  -c | --cran       prefered CRAN mirror                default: ${default_cran}
	  -M | --march      microarchitecture optimization flag default: ${default_march}
	  -g | --enable-git initialize with git                 default: false
	  -a | --activate   activates the new vsc-Rproject      default: false
	  -q | --quiet      hides info and warning messages     default: false
	  -h | --help       show this help message

	Examples:
	  vsc-rproject create MyProject -m modules.txt
	  vsc-rproject create -n MyProject -l \$VSC_DATA/MyRProjects/
	  vsc-rproject create --name MyProject --enable-git

	Note:
	  The modules.txt file is an optional but recommended file you can use
	  to list modules that need to be loaded upon activating the vsc-Rproject
	  environment. When you use this file, it must also provide the R module.

EOF
    }

    local project_name
    local modules_file
    local remaining_args
    local enable_git=false
    local activate_env=false

    # --- Parse Arguments --- #
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -n | --name)
          project_name="$2"
          shift 2
          ;;
        --name=*)
          project_name="${1#*=}"
          shift
          ;;
        -m | --modules)
          modules_file="$2"
          [[ "$modules_file" == ~* ]] && modules_file="${modules_file/#\~/$HOME}"
          shift 2
          ;;
        --modules=*)
          modules_file="${1#*=}"
          [[ "$modules_file" == ~* ]] && modules_file="${modules_file/#\~/$HOME}"
          shift
          ;;
        -l | --location)
          project_location="$(realpath -m "$2")"
          shift 2
          ;;
        --location=*)
          project_location="$(realpath -m "${1#*=}")"
          shift
          ;;
        -c | --cran)
          cran="$2"
          shift 2
         ;;
        --cran=*)
          cran="${1#*=}"
          shift
          ;;
        -M | --march)
          march="$2"
          shift 2
          ;;
        --march=*)
          march="${1#*=}"
          shift
          ;;
        -g | --enable-git)
          enable_git="true"
          shift
          ;;
        -a | --activate)
          activate_env="true"
          shift
          ;;
        -q | --quiet)
          quiet=true
          shift
          ;;
        -h | --help)
          usage_create
          return 0
          ;;
        -* | --*)
          echo_error "Unknown argument: $1"
          usage_create
          return 1
          ;;
        *)
          remaining_args+=("$1")
          shift
          ;;
      esac
    done

    if [[ ${#remaining_args[@]} -gt 1 ]]; then
      echo_error "Only one positional argument (project name) is allowed."
      usage_create
      return 1
    elif [[ ${#remaining_args[@]} -gt 0 ]]; then
      if [[ -n "$project_name" ]]; then
        echo_error "Project name can only be set once.";
        usage_create;
        return 1;
      fi;
      project_name="${remaining_args[0]}";
    fi;
   
    # --- Sanity checking --- # 
    check_project_name "${project_name}" || return 1 
    check_project_location "${project_location}" || return 1    
    if [[ -n "$modules_file" ]]; then
      check_modules_file "$modules_file" || return 1
    fi

    # --- Set project_root --- #
    local project_root="${project_location}/${project_name}"
  
    # --- Check if project is an existing vsc-Rproject --- #
    if is_vsc_rproject ${project_root}; then
      echo_warning "vsc-Rproject already exists at ${project_root}"
      read -p "Do you want to delete the existing project and start fresh? [y/N]: " response
      case ${response} in
        [yY][eE][sS]|[yY])
          local here="$(realpath ${PWD})"
          if [[ "${here}" == "${project_root}" || "${here}" == "${project_root}/"* ]]; then
            echo_error "Refusing to remove current working directory."
            return 1
          fi
          rm -rf "${project_root}"
          echo_info "vsc-Rproject directory reset."
          ;;
        *)
          echo_info "Aborted by user. No changes made."
          return 1
          ;;
      esac
    fi
  
    local vsc_r_libs='library/${VSC_OS_LOCAL}/R'
    local vsc_r_libs_xpnd="$(eval echo ${vsc_r_libs})"

    # --- Warn user if they have a virtual environment activated --- #
    if detect; then
      echo_warning "You already have an active vsc-Rproject environment."
      echo_warning "This vsc-Rproject environment will be deactivated."
      deactivate || return 1
    fi

    # --- Warn user if they have modules loaded --- #
    if [ $(get_nloaded_modules) -gt 0 ]; then
      echo_warning "You have $(get_nloaded_modules) loaded modules in the current shell. These modules will be purged."
      echo_warning "If you want to use these modules, please provide a modules file listing the required modules using the --modules or -m flag."
      echo_info "Purging currently loaded modules."
      module_purge_vsc_rproject
    fi

    # --- Loading the module environment --- #
    if [ -f "${modules_file}" ]; then
      echo_info "Loading modules from '${modules_file}'"
      if ! load_modules "${modules_file}"; then
        echo_error "Could not load modules from '${modules_file}'"
        return 1
      fi
      r_module="$(module list 2>&1 | grep -oP '\bR/[^\s]+' | head -n 1)"
      if [[ -z "${r_module}" ]]; then
        echo_error "No R module was loaded."
        return 1
      fi
      echo_info "Modules loaded successfully"
    else
      echo_warning "No module file provided. Proceeding with default: ${r_module}."
      echo_warning "Consider providing your desired R module using a modules.txt file."
      module load ${r_module}
    fi


    echo_info "Using ${r_module} to create vsc-Rproject environment at \"${project_root}\""

    # --- prepare vsc-Rproject directory --- #
    echo_info "Creating \$VSC_RPROJECT directory"
    mkdir -p "${project_root}/.R"
    mkdir -p "${project_root}/.vsc-rproject"
    mkdir -p "${project_root}/${vsc_r_libs_xpnd}"


    # --- Create modulesenv --- #
    echo_info "Storing modules.env"
    local project_modules="${project_root}/.vsc-rproject/modules.env"
    if [ -n "${modules_file}" ]; then
      cp ${modules_file} ${project_modules}
    else
      echo ${r_module} > ${project_modules}
    fi

    # --- Create Rproj --- #
    echo_info "Creating ${project_name}.Rproj"
    cat > "${project_root}/${project_name}.Rproj" <<-EOF
	Version: 1.0

	RestoreWorkspace: No
	SaveWorkspace: No
	AlwaysSaveHistory: Default

	EnableCodeIndexing: Yes
	UseSpacesForTab: Yes
	NumSpacesForTab: 2
	Encoding: UTF-8

	RnwWeave: knitr
	LaTeX: pdfLaTeX
EOF

    # --- Create Renviron --- #
    echo_info "Creating .Renviron"
    local renviron="${project_root}/.Renviron"
    local r_libs_path="${project_root}/${vsc_r_libs}"

    cat > "${renviron}" <<-EOF
	# Timezone setting
	TZ="Europe/Brussels"

	# Custom library path for R packages
	R_LIBS_USER="${r_libs_path}"
EOF

    # --- Create Rprofile --- #
    echo_info "Creating .Rprofile"

    local rprofile
    rprofile="${project_root}/.Rprofile"

    cat > ${rprofile} <<-EOF
	# Set CRAN Mirror
	options(repos = c(CRAN = "${cran}"))

	# Set R_MAKEVARS_USER path to project Makevars
	Sys.setenv(R_MAKEVARS_USER = file.path(getwd(), ".R/Makevars"))

	# Display informative message
	if (interactive()) {
	  cat(
	    "📁 R Project Environment Activated\n",
	    "\n🔹 Project       :", basename(getwd()),
	    "\n🔹 Working Dir   :", getwd(),
	    "\n🔹 Library Paths :\n  -",
	    paste(.libPaths(), collapse = "\n  - "),
	    "\n\n"
	  )
	}
EOF

    # --- Create Makevars --- #
    echo_info "Creating Makevars"
    local makevars="${project_root}/.R/Makevars"
    local makeconf="${EBROOTR}/lib/R/etc/Makeconf"

    echo "# Compiler flags for CPU microarchitecture optimization" > "${makevars}"
    grep -E "^\w+FLAGS\s*=.*-march=" "${makeconf}" | while read -r line; do
      varname=$(echo "${line}" | cut -d= -f1 | xargs)
      echo "${varname} += -march=${march}" >> "${makevars}"
    done


    # --- Initialize git --- #
    if [ "${enable_git}" = "true" ]; then
      echo_info "Initializing Git Repository..."
      git -C "${project_root}" init -b main
      cat > "${project_root}/.gitignore" <<-EOF
	.Rproj.user
	.Rhistory
	.RData
	.Ruserdata
	.Rout
	.Rout.save
	*.Rcheck/
	*.pdf
	.DS_Store
EOF

      git -C "${project_root}" add -A
      git -C "${project_root}" commit -m "Initial commit: created R project with Git"
      echo_info "Git initialized and first commit created."
    fi
    
    # --- Setup Summary --- #
    echo
    echo -e "${GREEN}vsc-Rproject environment setup complete.${RESET}"
    echo -e "${GREEN}========================================${RESET}"
    echo -e "${GREEN} >>> ${BRIGHT_GREEN}${project_root} ${GREEN}<<<${RESET}"
    echo

    # --- unload modules --- #
    module_purge_vsc_rproject

    # --- conditionally activate the new environment --- #
    if [[ "${activate_env}" == "true" ]]; then
      activate
    fi
  }


  subcmd_activate() {

    usage_activate() {
      cat <<-EOF

	Usage: vsc-rproject activate [OPTIONS]

	Options:
	  -n | --name       project name (required)         no default
	  -l | --location   project location                default: ${default_project_location}
	  -q | --quiet      hides info and warning messages
	  -h | --help       show this help message

EOF
    }

    local project_name
    local remaining_args

     # --- Parse Arguments --- #
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -n | --name)
          project_name="$2"
          shift 2
          ;;
        --name=*)
          project_name="${1#*=}"
          shift
          ;;
        -l | --location)
          project_location="$(realpath -m "$2")"
          shift 2
          ;;
        --location=*)
          project_location="$(realpath -m "${1#*=}")"
          shift
          ;;
        -q | --quiet)
          quiet=true
          shift
          shift
          ;;
        -h | --help)
          usage_activate
          return 0
          ;;
        -* | --*)
          echo_error "Unknown argument: $1"
          usage_activate
          return 1
          ;;
        *)
          remaining_args+=("$1")
          shift
          ;;
      esac
    done

    if [[ ${#remaining_args[@]} -gt 1 ]]; then
      echo_error "Only one positional argument (project name) is allowed."
      usage_activate
      return 1
    elif [[ ${#remaining_args[@]} -gt 0 ]]; then
      if [[ -n "$project_name" ]]; then
        echo_error "Project name can only be set once.";
        usage_activate;
        return 1;
      fi;
      project_name="${remaining_args[0]}";
    fi;

    # --- Sanity checking --- #
    check_project_name "${project_name}" || return 1
    check_project_location "${project_location}" || return 1

    # --- Set project_root --- #
    local project_root="${project_location}/${project_name}"

    if is_vsc_rproject ${project_root}; then

      # --- Warn user if they have a virtual environment activated --- #
      if detect; then
        if [[ "${VSC_RPROJECT}" ==  "${project_root}"  ]]; then
          echo_info "${project_name} is already active."
          return 0
        fi
        echo_warning "You already have an active vsc-Rproject environment."
        echo_warning "This vsc-Rproject environment will be deactivated."
        deactivate
      fi

      # --- Warn user if they have modules loaded --- #
      if [ $(get_nloaded_modules) -gt 0 ]; then
        echo_warning "You have $(get_nloaded_modules) loaded modules in the current shell. These modules will be purged."
        module_purge
      fi

      # --- Activate the environment --- #
      activate
    else
      echo_error "${project_root} is not an RStudio Project"
      return 1
    fi
  }


  subcmd_deactivate() {

    usage_deactivate() {
      cat <<-EOF

	Usage: vsc-rproject deactivate

	Options:
	  -q | --quiet      hides info and warning messages
	  -h | --help       shows this help message

EOF
    }

    # --- Parse Arguments --- #
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -h | --help)
          usage_deactivate
          return 0
          ;;
        -q | --quiet)
          quiet=true
          shift
          ;;
        -* | --*)
          echo_error "Unknown argument: $1"
          usage_deactivate
          return 1
          ;;
        *)
          echo_error "Unexpected argument: $1"
          usage_deactivate
          return 1
          ;;
      esac
    done

    deactivate || return 1
  }

  subcmd_configure() {

    local configs="${VSC_RPROJECT_CONFIG:-${VSC_HOME}/.vsc-rproject-config}"
    usage_configure() {
      cat <<-EOF

	Usage: vsc-rproject configure [OPTIONS]

	Options:
	  -R | --default-r  sets default R module (e.g. ${__vscrproject__default_r})
	  -l | --location   sets default project location
	  -c | --cran       sets default CRAN mirror
	  -M | --march      sets default -march compiler option
	  -r | --reset      resets default config values
	  -q | --quiet      hides info and warning messages
	  -h | --help       shows this help message

EOF
    }

    configure() {
      local key="$1"
      local value="$2"

      local escaped_key=$(printf '%s' "${key}" | sed 's/[][\.^$*]/\\&/g')
      
      touch "${configs}"
      # If key exists, replace its value
      if grep -qE "^${escaped_key}=" "${configs}"; then
        sed -i.bak -E "s|^${escaped_key}=.*|${key}=\"${value}\"|" "${configs}"
        rm -f "${configs}.bak"
      else
        echo "${key}=\"${value}\"" >> "${configs}"
      fi

      echo_info "Set ${key} to: ${value}"
    }

    reset_config() {
      if [[ -f ${configs}  ]]; then 
        read -p "Are you certain you want to reset your vsc-Rproject settings? [y/N]: " response
        case ${response} in
          [yY][eE][sS]|[yY])
            rm ${configs}
            echo_info "vsc-Rproject settings have been reset"
            return 0
            ;;
          *)
            echo_info "Aborted by user. No changes made."
            return 1
            ;;
        esac
      else
        echo_info "vsc-Rproject settings already at default"
        return 0
      fi
    }

    if [[ $# -eq 0 ]]; then
      echo_error "No arguments provided."
      usage_configure
      return 1
    fi

    # --- Parse Arguments --- #
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -R | --default-r)
          default_r_module="$2"
          module_exists "${default_r_module}" || return 1
          configure "default_r_module" ${default_r_module}
          shift 2
          ;;
        --default-r=*)
          default_r_module="${1#*=}"
          module_exists "${default_r_module}" || return 1
          configure "default_r_module" ${default_r_module}
          shift
          ;;
        -l | --location)
          default_project_location="$(realpath -m "$2")"
          check_project_location "${default_project_location}" || return 1
          configure "default_project_location" ${default_project_location}
          shift 2
          ;;
        --location=*)
          default_project_location=$(realpath -m "${1#*=}")
          check_project_location "${default_project_location}" || return 1
          configure "default_project_location" ${default_project_location}
          shift
          ;;
        -c | --cran)
          default_cran="$2"
          configure "default_cran" ${default_cran}
          shift 2
         ;;
        --cran=*)
          default_cran="${1#*=}"
          configure "default_cran" ${default_cran}
          shift
          ;;
        -M | --march)
          default_march="$2"
          configure "default_march" ${default_march}
          shift 2
          ;;
        --march=*)
          default_march="${1#*=}"
          configure "default_march" ${default_march}
          shift
          ;;
        -h | --help)
          usage_configure
          return 0
          ;;
        -r | --reset)
          reset_config || return 1
          return 0
          ;;
        -q | --quiet)
          quiet=true
          shift
          ;;
        -* | --*)
          echo_error "Unknown argument: $1"
          usage_configure
          return 1
          ;;
        *)
          echo_error "Unexpected argument: $1"
          usage_configure
          return 1
          ;;
      esac
    done
  }  


  # === Sub-Command Dispatcher === #

  local subcommand="${1}"

  local default_r_module
  local default_project_location
  local default_cran
  local default_march

  # --- setting defaults --- #
  if [[ -n $VSC_RPROJECT_CONFIG && ! -f $VSC_RPROJECT_CONFIG ]]; then
    echo_error "$VSC_RPROJECT_CONFIG is not a file"
    return 1
  else
    eval $(load_defaults) 
  fi

  local quiet=false
  local r_module="${default_r_module}"
  local project_location="${default_project_location}"
  local cran="${default_cran}"
  local march="${default_march}"

  shift || true

  case "$subcommand" in
    [Cc]reate)
      subcmd_create "$@"
      ;;
    [Aa]ctivate)
      subcmd_activate "$@"
      ;;
    [Dd]eactivate)
      subcmd_deactivate "$@"
      ;;
    [Cc]onfigure)
      subcmd_configure "$@"
      ;;
    -d|--defaults)
      show_default_settings
      return 0
      ;;
    -v|--version)
      echo $VSC_RPROJECT_VERSION
      return 0
      ;;
    -h|--help)
      usage
      return 0
      ;;
    *)
      echo_error "Unknown command: $subcommand"
      usage
      return 1
      ;;
  esac
}
