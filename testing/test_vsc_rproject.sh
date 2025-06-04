#!/bin/bash

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
WHITE='\033[1;37m'
NC='\033[0m'

write_log() {
  echo "${1}" >> "${TEST_LOG}"
}

# Setup and Cleanup functions
setup() {
  echo "============================"
  echo " Preparing Test Environment "
  echo "============================"
  PREV_DIR="$(pwd)"

  echo "preparing log file"
  TEST_LOG="${PREV_DIR}/test.log"
  [[ -f "${TEST_LOG}" ]] && rm "${TEST_LOG}"
  touch "${TEST_LOG}"
  write_log "# ===== vsc-Rproject Tests ===== #"

  echo "creating test dir..."
  TEST_DIR="${VSC_SCRATCH}/vsc-Rproject_testing"
  mkdir -p "${TEST_DIR}"

  VERSION="1.0.0"

  DEFAULT_R_MODULE="R/4.4.2-gfbf-2024a"
  R_MODULE="R/4.4.1-gfbf-2023b"
  BAD_R_MODULE="R/4.2.2"

  DEFAULT_LOCATION="${VSC_DATA}/Rprojects"
  TRUE_DEFAULT_LOCATION="$(realpath ${DEFAULT_LOCATION})"
  LOCATION="${TEST_DIR}"
  TRUE_LOCATION="$(realpath $TEST_DIR)"
  BAD_LOCATION="$VSC_SCRATCH/bad path"

  DEFAULT_CRAN="https://cloud.r-project.org"
  CRAN="https://ftp.belnet.be/mirror/CRAN/"

  DEFAULT_MARCH="x86-64-v4"
  MARCH="skylake"

  NAME1="GoodName"
  NAME2="ModulesTest"
  BAD_NAME="Bad Name!"

  GOOD_MODULES_FILE="$TEST_DIR/.good_modules.txt"
  echo "${R_MODULE}" > "$GOOD_MODULES_FILE"
  echo "JAGS/4.3.2-foss-2023b" >> "$GOOD_MODULES_FILE"
  BAD_MODULES_FILE="$TEST_DIR/.bad_modules.txt"
  echo "JAGS/4.3.2-foss-2023b" > "$BAD_MODULES_FILE" # no R module in the modules file

  TEST_CONFIG="${VSC_HOME}/.vsc-rproject-config"
  if [[ -f "${TEST_CONFIG}" ]]; then
    echo "storing user .vsc-rproject-config file..."
    USER_CONFIG="${VSC_HOME}/.vsc-rproject-config-user"
    mv "${TEST_CONFIG}" "${USER_CONFIG}"
  fi

  cd "${TEST_DIR}" || exit 1

  echo "cleaning up modules"
  module purge &> /dev/null

  echo "loading vsc-Rproject"
  module load vsc-Rproject
}

cleanup() {
  echo "==========================="
  echo " Cleaning Test Environment "
  echo "==========================="

  cd "${PREV_DIR}"

  echo removing test dir...
  rm -rf "${TEST_DIR}"

  if [[ -f "${USER_CONFIG}" ]]; then
    echo "restoring user .vsc-rproject-config file..."
    mv "${USER_CONFIG}" "${TEST_CONFIG}"
  fi

  echo "cleaning up modules"
  module purge &> /dev/null
}

# Generic test function
run_test() {

  echo_test() {
    echo -e "${WHITE}${1}${NC}"
  }

  echo_pass() {
    echo -e "${GREEN}  ${1} ✅${NC}"
  }

  echo_fail() {
    echo -e "${RED}  ${1} ❌${NC}"
  }

  local test_name
  local command
  local expected_status=0
  local expected_output

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name | -n)
        test_name="$2"
        shift 2
        ;;
      --command | -c)
        command="$2"
        shift 2
        ;;
      --status | -s)
        expected_status="$2"
        shift 2
        ;;
      --output | -o)
        expected_output="$2"
        shift 2
        ;;
      *)
        echo "Unknown argument: $1"
        return 1
        ;;
    esac
  done

  echo_test "$test_name"

  write_log "=========================================================="
  write_log "TEST: $test_name"
  local result

  result=$(
    eval "$command"
    echo "::STATUS::$?"
  )
  write_log "# --- Command Output --- #"
  write_log "${result}"
  # Extract the status from the output
  status=$(echo "$result" | awk -F'::STATUS::' '{print $2}')
  output=$(echo "$result" | sed '/::STATUS::/d')

  write_log "# --- Test Results --- #"
  if [ $status -eq $expected_status ]; then
    echo_pass "status"
    write_log "PASS: $test_name - status"
  else
    echo_fail "status"
    write_log "FAIL: $test_name - status"
    write_log "  status: $status"
    write_log "  expected: $expected_status"
  fi
  if [ -n "$expected_output" ]; then
    if echo "$output" | grep -q "$expected_output"; then
      echo_pass "output"
      write_log "PASS: $test_name - output" >> "${TEST_LOG}"
    else
      echo_fail "output"
      write_log "FAIL: $test_name - output"
      write_log "  output: $output"
      write_log "  expected: $expected_output"
    fi
  fi
}

# ========================= #
# vsc-rproject main - tests #
# ========================= #
main_tests() {
  write_log ""
  write_log "# ========================= #"
  write_log "# vsc-rproject main - tests #"
  write_log "# ========================= #"
  write_log ""

  # --- positive tests --- #
  run_test -n "vsc-Rproject help" -c "vsc-rproject --help"
  run_test -n "vsc-Rproject version" -c "vsc-rproject --version" -o "${VERSION}"
  run_test -n "vsc-Rproject defaults | with ${TEST_CONFIG}" -c "vsc-rproject --defaults" -o "${TEST_CONFIG}"
  run_test -n "- check: R" -c "vsc-rproject --defaults" -o "${DEFAULT_R_MODULE}"
  run_test -n "- check: location" -c "vsc-rproject --defaults" -o "${TRUE_DEFAULT_LOCATION}"
  run_test -n "- check: CRAN" -c "vsc-rproject --defaults" -o "${DEFAULT_CRAN}"
  run_test -n "- check: march" -c "vsc-rproject --defaults" -o "${DEFAULT_MARCH}"

  # --- negative tests --- #
  run_test -n "vsc-Rproject unknown subcommand" -c "vsc-rproject bad_command" -s 1 -o "Unknown command: bad_command"
}

# ============================== #
# vsc-rproject configure - tests #
# ============================== #
configure_tests() {
  write_log ""
  write_log "# ============================== #"
  write_log "# vsc-rproject configure - tests #"
  write_log "# ============================== #"
  write_log ""

  # --- positive tests --- #
  # vsc-rproject configure --help
  run_test -n "Configure help" -c "vsc-rproject configure --help"

  # configuring default settings
  run_test -n "Configure default with existing R" -c 'vsc-rproject configure -R ${R_MODULE}' -o "Set default_r_module to: ${R_MODULE}"
  run_test -n "Configure default location with /good/path" -c 'vsc-rproject configure -l "${LOCATION}"' -o "Set default_project_location to: ${TRUE_LOCATION}"
  run_test -n "Configure default CRAN" -c 'vsc-rproject configure -c ${CRAN}' -o "Set default_cran to: ${CRAN}"
  run_test -n "Configure default march" -c 'vsc-rproject configure -M ${MARCH}' -o "Set default_march to: ${MARCH}"

  # check if new defaults are shown with vsc-rproject --defaults
  run_test -n "vsc-Rproject updated defaults" -c "vsc-rproject --defaults" -o "${TEST_CONFIG}"
  run_test -n "- check: updated R" -c 'vsc-rproject --defaults' -o "${R_MODULE}"
  run_test -n "- check: updated location" -c 'vsc-rproject --defaults' -o "${TRUE_LOCATION}"
  run_test -n "- check: updated CRAN" -c 'vsc-rproject --defaults' -o "${CRAN}"
  run_test -n "- check: updated march" -c 'vsc-rproject --defaults' -o "${MARCH}"
  run_test -n "- check: content of ${TEST_CONFIG}" -c "cat ${TEST_CONFIG}" -o "${R_MODULE}"


  # resetting defaults
  run_test -n "Configure reset ${TEST_CONFIG}" -c 'vsc-rproject configure --reset <<< "yes"' -o "vsc-Rproject settings have been reset"
  run_test -n "- check: ${TEST_CONFIG} empty" -c '! [[ -s "${TEST_CONFIG}" ]]'
  run_test -n "Configure reset | already default settings" -c 'vsc-rproject configure -r <<< "yes"' -o "vsc-Rproject settings already at default"

  # use alternative config via $VSC_RPROJECT_CONFIG
  VSC_RPROJECT_CONFIG=~/.vsc-rproject-config-test
  touch "${VSC_RPROJECT_CONFIG}"

  run_test -n "vsc-Rproject defaults | with ${VSC_RPROJECT_CONFIG}" -c 'vsc-rproject --defaults' -o "${VSC_RPROJECT_CONFIG}"
  run_test -n "Configure default location in ${VSC_RPROJECT_CONFIG}" -c 'vsc-rproject configure -l ${LOCATION}' -o "Set default_project_location to: ${TRUE_LOCATION}"
  run_test -n "- check: content of ${VSC_RPROJECT_CONFIG}" -c 'cat ${VSC_RPROJECT_CONFIG}' -o "${TRUE_LOCATION}"
  run_test -n "Configure reset | ${VSC_RPROJECT_CONFIG}" -c 'vsc-rproject configure -r <<< "yes"' -o "vsc-Rproject settings have been reset"
  run_test -n "- check: $VSC_RPROJECT_CONFIG empty" -c '! [[ -s "${VSC_RPROJECT_CONFIG}" ]]'

  rm $VSC_RPROJECT_CONFIG
  unset VSC_RPROJECT_CONFIG

  # --- negative tests --- #
  run_test -n "Configure default with non-existing R" -c 'vsc-rproject configure -R ${BAD_R_MODULE}' -s 1 -o "${BAD_R_MODULE} not found."
  run_test -n "configure default location with /bad path" -c 'vsc-rproject configure -l "${VSC_SCRATCH}/bad path"' -s 1 -o "Only these characters are accepted: a-z, A-Z, 0-9, /, _, -, and ."
}

# =========================== #
# vsc-rproject create - tests #
# =========================== #
create_tests() {
  write_log ""
  write_log "# =========================== #"
  write_log "# vsc-rproject create - tests #"
  write_log "# =========================== #"
  write_log ""

  # --- positive tests --- #
  # vsc-rproject create --help
  run_test -n "Create help" -c "vsc-rproject create --help"
  run_test -n "- check: default R" -c "vsc-rproject create --help" -o "${DEFAULT_R_MODULE}"
  run_test -n "- check: default location" -c "vsc-rproject create --help" -o "${TRUE_DEFAULT_LOCATION}"
  run_test -n "- check: default CRAN" -c "vsc-rproject create --help" -o "${DEFAULT_CRAN}"
  run_test -n "- check: default march" -c "vsc-rproject create --help" -o "${DEFAULT_MARCH}"
  run_test -n "Create help - additional arg" -c 'vsc-rproject create --location=${LOCATION} --help' -o "${TRUE_DEFAULT_LOCATION}"

  # creating a vsc-Rproject
  run_test -n "Create project" -c 'vsc-rproject create "${NAME1}" -l "${LOCATION}"' -o "vsc-Rproject environment setup complete"
  run_test -n "- check: project_root exists" -c '[[ -d "${LOCATION}/${NAME1}" ]]'
  run_test -n "- check: Rlibrary exists" -c '[[ -d "${LOCATION}/${NAME1}/library/${VSC_OS_LOCAL}/R" ]]'
  run_test -n "- check: .Rprofile content" -c 'cat "${LOCATION}/${NAME1}/.Rprofile"' -o "options(repos = c(CRAN = \"${DEFAULT_CRAN}\"))"
  run_test -n "- check: .Renviron content" -c 'cat "${LOCATION}/${NAME1}/.Renviron"' -o "R_LIBS_USER=\"${TRUE_LOCATION}/${NAME1}/library/\${VSC_OS_LOCAL}/R\""
  run_test -n "- check: Makevars content" -c 'cat "${LOCATION}/${NAME1}/.R/Makevars"' -o "${DEFAULT_MARCH}"
  run_test -n "- check: modules.env content" -c 'cat "${LOCATION}/${NAME1}/.vsc-rproject/modules.env"' -o "${DEFAULT_R_MODULE}"

  run_test -n "Overwrite existing project | no" -c 'vsc-rproject create "${NAME1}" -l "${LOCATION}" <<< no' -s 1 -o "Aborted by user. No changes made."
  run_test -n "Overwrite existing project | yes" -c 'vsc-rproject create "${NAME1}" -l "${LOCATION}" <<< yes' -o "vsc-Rproject environment setup complete"

  # update defaults and test project creation with new default settings
  vsc-rproject configure -R "${R_MODULE}" --location "${LOCATION}" --cran="${CRAN}" -M "skylake" >> "${TEST_LOG}"

  # vsc-rproject create --help with new defaults
  run_test -n "Create help - updated defaults" -c "vsc-rproject create --help"
  run_test -n "- check: updated R" -c "vsc-rproject create --help" -o "${R_MODULE}"
  run_test -n "- check: updated location" -c "vsc-rproject create --help" -o "${TRUE_LOCATION}"
  run_test -n "- check: updated CRAN" -c "vsc-rproject create --help" -o "${CRAN}"
  run_test -n "- check: updated march" -c "vsc-rproject create --help" -o "${MARCH}"

  # creating a vsc-Rproject with new defaults
  run_test -n "Create project_1 with new default settings" -c 'vsc-rproject create "${NAME1}" <<< "yes"' -o "vsc-Rproject environment setup complete"
  run_test -n "- check: updated project_root" -c '[[ -d "${LOCATION}/${NAME1}" ]]'
  run_test -n "- check: updated .Rprofile" -c 'cat "${LOCATION}/${NAME1}/.Rprofile"' -o "options(repos = c(CRAN = \"${CRAN}\"))"
  run_test -n "- check: updated Makevars" -c 'cat "${LOCATION}/${NAME1}/.R/Makevars"' -o "${MARCH}"
  run_test -n "- check: updated modules.env" -c 'cat "${LOCATION}/${NAME1}/.vsc-rproject/modules.env"' -o "${R_MODULE}"

  # creating a vsc-Rproject with --enable-git
  run_test -n "Create project_1 with --enable-git" -c 'vsc-rproject create "${NAME1}" --enable-git <<< "yes"' -o "Git initialized and first commit created."

  # reset vsc-Rproject settings
  vsc-rproject configure --reset <<< "yes" >> "${TEST_LOG}"

  # creating a vsc-Rproject with modules.txt file
  run_test -n "Create project_2 with good_modules_file" -c 'vsc-rproject create ${NAME2} -l ${LOCATION} -m ${GOOD_MODULES_FILE}' -o "Modules loaded successfully"
  run_test -n "- check: updated modules.env" -c 'cat "${LOCATION}/${NAME1}/.vsc-rproject/modules.env"' -o "${R_MODULE}"

  # --- negative tests --- #
  run_test -n "Create project with bad name" -c 'vsc-rproject create --name="${BAD_NAME}"' -s 1 -o "Invalid name"
  run_test -n "Create project with double name" -c 'vsc-rproject create "${NAME1}" --name="${NAME1}"' -s 1 -o "Project name can only be set once"
  run_test -n "Create project with two positional arguments" -c 'vsc-rproject create "${NAME1}" "${NAME1}"' -s 1 -o "Only one positional argument (project name) is allowed."
  run_test -n "Create project without name" -c 'vsc-rproject create' -s 1 -o "Project name must be provided"
  run_test -n "Create project with bad_modules_file" -c 'vsc-rproject create ${NAME2} -m ${BAD_MODULES_FILE} <<< yes' -s 1 -o "No R module was loaded."
  run_test -n "Create project with non-existing modules_file" -c 'vsc-rproject create ${NAME2} -l ${LOCATION} -m ${GOOD_MODULES_FILE}_FAKE' -s 1 -o "Modules file not found."
}

# ============================= #
# vsc-rproject activate - tests #
# ============================= #
activate_tests() {
  write_log ""
  write_log "# ============================= #"
  write_log "# vsc-rproject activate - tests #"
  write_log "# ============================= #"
  write_log ""

  vsc-rproject create "${NAME1}" -l "${LOCATION}"  <<< "yes" >> "${TEST_LOG}"
  vsc-rproject create "${NAME2}" -l "${LOCATION}" -m "${GOOD_MODULES_FILE}" <<< "yes" >> "${TEST_LOG}"

  # --- positive tests --- #
  # vsc-rproject activate --help
  run_test -n "Activate help" -c 'vsc-rproject activate --help' -o "${TRUE_DEFAULT_LOCATION}"
  run_test -n "Activate help - additional arg" -c 'vsc-rproject activate --location=${LOCATION} --help' -o "${TRUE_DEFAULT_LOCATION}"

  # activating a vsc-Rproject

  run_test -n "Activate project_1 | default settings" -c 'vsc-rproject activate "${NAME1}" -l "${LOCATION}"' -s 0 -o "${NAME1} activated"
  run_test -n "- check: \$VSC_RPROJECT" -c 'vsc-rproject activate "${NAME1}" -l "${LOCATION}"; echo $VSC_RPROJECT' -o "${TRUE_LOCATION}/${NAME1}"
  run_test -n "- check: R module loaded" -c 'vsc-rproject activate "${NAME1}" -l "${LOCATION}"; echo $(module --terse --redirect list)' -o "${DEFAULT_R_MODULE}"

  run_test -n "Activate project_2 | modules file" -c 'vsc-rproject activate "${NAME2}" -l ${LOCATION}' -s 0 -o "${NAME2} activated"
  run_test -n "- check: \$VSC_RPROJECT" -c 'vsc-rproject activate "${NAME2}" -l "${LOCATION}"; echo $VSC_RPROJECT' -o "${TRUE_LOCATION}/${NAME2}"
  run_test -n "- check: R module loaded" -c 'vsc-rproject activate "${NAME2}" -l "${LOCATION}"; echo $(module --terse --redirect list)' -o "${R_MODULE}"

  # --- negative tests --- #
  run_test -n "Activate project without name" -c 'vsc-rproject activate --location ${LOCATION}' -s 1 -o "Project name must be provided"
  run_test -n "Activate project with bad name" -c 'vsc-rproject activate --name "${BAD_NAME}" --location "${LOCATION}"' -s 1 -o "Invalid name"
  run_test -n "Activate non-existing project" -c 'vsc-rproject activate --name="NotAProject" --location="${LOCATION}"' -s 1 -o "is not an RStudio Project"
}

# ============================== #
# vsc-rproject deactivate -tests #
# ============================== #
deactivate_tests() {
  write_log ""
  write_log "# =============================== #"
  write_log "# vsc-rproject deactivate - tests #"
  write_log "# =============================== #"
  write_log ""

  vsc-rproject create "${NAME1}" -l "${LOCATION}"  <<< "yes" >> "${TEST_LOG}"

  # --- positive tests --- #
  run_test -n "Dectivate help" -c 'vsc-rproject deactivate --help'
  run_test -n "Deactivate project" -c 'vsc-rproject activate ${NAME1} -l ${LOCATION}; vsc-rproject deactivate' -o "has been deactivated"

  # --- negative tests --- #
  run_test -n "Deactivate project without active project" -c 'vsc-rproject deactivate' -s 1
}

# =================== #
# Parsing Tests Cases #
# =================== #

setup
trap cleanup EXIT
echo "==============="
echo " Running Tests "
echo "==============="

if [[ $# -eq 0 ]]; then
  main_tests
  configure_tests
  create_tests
  activate_tests
  deactivate_tests
else
  while [[ $# -gt 0 ]]; do
    case "$1" in
      main)
        main_tests
        shift
        ;;
      configure)
        configure_tests
        shift
        ;;
      create)
        create_tests
        shift
        ;;
      activate)
        activate_tests
        shift
        ;;
      deactivate)
        deactivate_tests
        shift
        ;;
      *)
        echo "Unknown test: $1"
        return 1
        ;;
    esac
  done
fi
