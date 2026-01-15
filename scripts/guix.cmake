cmake_host_system_information(RESULT HOST_NAME QUERY HOSTNAME)

set(CTEST_SITE ${HOST_NAME})
set(CTEST_BUILD_NAME "Guix")
set(CTEST_SOURCE_DIRECTORY "/data/bitcoin")
set(CTEST_BINARY_DIRECTORY "/data/bitcoin")

set(CTEST_BUILD_COMMAND "bash -c \"unset SOURCE_DATE_EPOCH && git fetch origin && git reset --hard origin/master && ${CTEST_SOURCE_DIRECTORY}/contrib/guix/guix-build\"")

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
