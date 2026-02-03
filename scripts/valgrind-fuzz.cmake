set(CTEST_SITE $ENV{SITE_NAME})
set(CTEST_SOURCE_DIRECTORY $ENV{BITCOIN_PATH})
set(CTEST_BINARY_DIRECTORY "/data/build")
set(CTEST_BUILD_NAME "valgrind-fuzz")
set(CTEST_GIT_COMMAND "git")

set(QA_ASSETS_PATH $ENV{QA_ASSETS_PATH})
set(BUILD_DIR ${CTEST_BINARY_DIRECTORY})

execute_process(
  COMMAND git rev-parse HEAD
  WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
  OUTPUT_VARIABLE OLD_HEAD
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

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

  # Pull latest qa-assets while waiting
  execute_process(
    COMMAND git pull
    WORKING_DIRECTORY ${QA_ASSETS_PATH}
  )

  if(NOT OLD_HEAD STREQUAL NEW_HEAD)
    break()
  endif()
  message("No new commits (at ${OLD_HEAD}), sleeping 60s")
  execute_process(COMMAND sleep 60)
endwhile()

# Pull qa-assets once more before building
execute_process(
  COMMAND git pull
  WORKING_DIRECTORY ${QA_ASSETS_PATH}
)

execute_process(
  COMMAND git clean -dfx
    --exclude=CTestConfig.cmake
    --exclude=CTestCustom.cmake
    --exclude=CMakeUserPresets.json
  WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
)

ctest_start(Continuous)
ctest_update()
ctest_configure(OPTIONS "--preset;valgrind-fuzz")
ctest_build()

set(FUZZ_OUTPUT_FILE "${BUILD_DIR}/fuzz-output.txt")
execute_process(
  COMMAND ${BUILD_DIR}/test/fuzz/test_runner.py
    --valgrind
    -l DEBUG
    ${QA_ASSETS_PATH}/fuzz_corpora/
    --empty_min_time=60
  WORKING_DIRECTORY ${BUILD_DIR}
  RESULT_VARIABLE FUZZ_RESULT
  OUTPUT_FILE ${FUZZ_OUTPUT_FILE}
  ERROR_FILE ${FUZZ_OUTPUT_FILE}
)

if(NOT FUZZ_RESULT EQUAL 0)
  message(SEND_ERROR "Fuzz test_runner.py failed with exit code ${FUZZ_RESULT}")
endif()

if(EXISTS "${FUZZ_OUTPUT_FILE}")
  set(CTEST_NOTES_FILES "${FUZZ_OUTPUT_FILE}")
endif()

ctest_submit()
