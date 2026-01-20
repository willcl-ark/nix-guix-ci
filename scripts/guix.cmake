set(CTEST_SITE $ENV{SITE_NAME})
set(CTEST_SOURCE_DIRECTORY $ENV{BITCOIN_PATH})
set(CTEST_BINARY_DIRECTORY $ENV{BITCOIN_PATH})

# We fetch manually rather than with ctest_update() as we want to set
# CTEST_BUILD_NAME dynamically, but ctest_update() must run after
# ctest_start(), which needs the name set
execute_process(
  COMMAND git rev-parse HEAD
  WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
  OUTPUT_VARIABLE OLD_HEAD
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
# Poll until a new commit is available
while(TRUE)
  execute_process(
    COMMAND git fetch origin
    WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
  )
  execute_process(
    COMMAND git rev-parse origin/master
    WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
    OUTPUT_VARIABLE NEW_HEAD
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(NOT OLD_HEAD STREQUAL NEW_HEAD)
    break()
  endif()
  message("No new commits (at ${OLD_HEAD}), sleeping 60s")
  execute_process(COMMAND sleep 60)
endwhile()

execute_process(
  COMMAND git reset --hard ${NEW_HEAD}
  WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
)
string(SUBSTRING "${NEW_HEAD}" 0 12 GIT_REV)
set(CTEST_BUILD_NAME "guix-${GIT_REV}")

set(CTEST_BUILD_COMMAND "bash -c \"unset SOURCE_DATE_EPOCH && ${CTEST_SOURCE_DIRECTORY}/contrib/guix/guix-build\"")

file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}/Testing")

execute_process(
  COMMAND git clean -dfx --exclude=CTestConfig.cmake
  WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
)

ctest_start(Continuous TRACK "Guix")
ctest_build()

# Add guix hashes as a note
set(HASH_FILE "${CTEST_BINARY_DIRECTORY}/build-hashes.txt")
execute_process(
  COMMAND bash -c "
    REV=\$(git rev-parse --short=12 HEAD)
    BUILD_DIR=\"guix-build-\${REV}\"
    if [ -d \"\${BUILD_DIR}/output\" ]; then
      uname -m > \"${HASH_FILE}\"
      find \"\${BUILD_DIR}/output/\" -type f -print0 | env LC_ALL=C sort -z | xargs -r0 sha256sum >> \"${HASH_FILE}\"
    fi
  "
  WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
)
if(EXISTS "${HASH_FILE}")
  set(CTEST_NOTES_FILES "${HASH_FILE}")
endif()

ctest_submit()
