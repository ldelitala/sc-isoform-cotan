test_that("config_workflow creates the log file and rotates its name", {
    log_dir <- tempfile("logs")

    suppressMessages(config_workflow(output_dir = log_dir, file_name = "run.log", logging_level = 3L))
    expect_true(file.exists(file.path(log_dir, "run.log")))

    # a second run in the same directory must not overwrite the first log
    suppressMessages(config_workflow(output_dir = log_dir, file_name = "run.log", logging_level = 3L))
    expect_true(file.exists(file.path(log_dir, "run_1.log")))

    suppressMessages(config_workflow(output_dir = log_dir, file_name = "run.log", logging_level = 3L))
    expect_true(file.exists(file.path(log_dir, "run_2.log")))
})

test_that("log calls append to the configured log file", {
    log_dir <- tempfile("logs")
    suppressMessages(config_workflow(output_dir = log_dir, file_name = "run.log", logging_level = 3L))

    suppressMessages(log_info("first-line"))
    suppressMessages(log_stat("second-line"))

    lines <- readLines(file.path(log_dir, "run.log"), warn = FALSE)
    expect_true(any(grepl("first-line", lines)))
    expect_true(any(grepl("second-line", lines)))
    expect_gt(length(lines), 2L)   # the workflow header lines are in there too
})

test_that("log_error with stop_exec aborts", {
    expect_error(suppressMessages(log_error("boom", stop_exec = TRUE)), "boom")
})

test_that("reset_log_state empties the depth stack", {
    state <- get(".log_state", envir = asNamespace("cotanisoform"))

    suppressMessages(log_header("open block"))
    expect_gt(length(state$depth_stack), 0L)

    suppressMessages(reset_log_state())
    expect_length(state$depth_stack, 0L)
})
