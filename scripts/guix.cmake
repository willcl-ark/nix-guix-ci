set(CTEST_SITE $ENV{SITE_NAME})
set(CTEST_SOURCE_DIRECTORY $ENV{BITCOIN_PATH})
set(CTEST_BINARY_DIRECTORY $ENV{BITCOIN_PATH})
set(CTEST_BUILD_NAME "guix")
set(CTEST_BUILD_COMMAND "bash -c \"unset SOURCE_DATE_EPOCH && ${CTEST_SOURCE_DIRECTORY}/contrib/guix/guix-build\"")

# Poll until a new commit is available
while(TRUE)
  # Cleanup first
  execute_process(
    COMMAND git clean -dfx --exclude=CTestConfig.cmake
    WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
    )

  # Start a new run
  ctest_start(Continuous TRACK "Guix")
  ctest_update(RETURN_VALUE UPDATE_COUNT)
  if(UPDATE_COUNT GREATER 0)
    # If we detect a new update, break out of the loop and run the build
    break()
  endif()
  execute_process(
    COMMAND git rev-parse HEAD
    WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
    OUTPUT_VARIABLE CURRENT_HEAD
    OUTPUT_STRIP_TRAILING_WHITESPACE
    )
  message("No new commits (at ${CURRENT_HEAD}), sleeping 60s")
  execute_process(COMMAND sleep 60)
endwhile()

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
