cmake_host_system_information(RESULT OS_PLATFORM QUERY OS_PLATFORM)

set(CTEST_SITE "${OS_PLATFORM}-nixos-ryzen5")
set(CTEST_SOURCE_DIRECTORY "/data/bitcoin")
set(CTEST_BINARY_DIRECTORY "/data/bitcoin")

# Fetch, reset, then get commit hash for build name
execute_process(
  COMMAND git fetch origin
  WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
)
execute_process(
  COMMAND git reset --hard origin/master
  WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
)
execute_process(
  COMMAND git rev-parse --short=12 HEAD
  WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
  OUTPUT_VARIABLE GIT_REV
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(CTEST_BUILD_NAME "Guix-${GIT_REV}")

set(CTEST_BUILD_COMMAND "bash -c \"unset SOURCE_DATE_EPOCH && ${CTEST_SOURCE_DIRECTORY}/contrib/guix/guix-build\"")

file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}/Testing")

# Make sure we are clean
execute_process(
  COMMAND git clean -dfx --exclude=CTestConfig.cmake
  WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
)

ctest_start("Continuous")

ctest_build()

# Uploade guix hashes as an artifact
execute_process(
  COMMAND bash -c "
    REV=$(git rev-parse --short=12 HEAD)
    BUILD_DIR=\"guix-build-${REV}\"
    HASH_FILE=\"${CTEST_BINARY_DIRECTORY}/Testing/build-hashes.txt\"
    if [ -d \"${BUILD_DIR}/output\" ]; then
      uname -m > \"${HASH_FILE}\"
      find \"${BUILD_DIR}/output/\" -type f -print0 | env LC_ALL=C sort -z | xargs -r0 sha256sum >> \"${HASH_FILE}\"
    fi
  "
  WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
)
if(EXISTS "${CTEST_BINARY_DIRECTORY}/Testing/build-hashes.txt")
  ctest_upload(FILES "${CTEST_BINARY_DIRECTORY}/Testing/build-hashes.txt")
endif()

ctest_submit()
