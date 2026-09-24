test_that("get_uniform_vector names every barcode and repeats the value", {
    tsv <- tempfile(fileext = ".tsv")
    writeLines(c("bc1", "bc2", "bc3"), tsv)

    vec <- suppressMessages(get_uniform_vector(tsv))
    expect_length(vec, 3L)
    expect_identical(names(vec), c("bc1", "bc2", "bc3"))
    expect_true(all(vec))

    typed <- suppressMessages(get_uniform_vector(tsv, value = "A549"))
    expect_identical(unname(typed), rep("A549", 3L))
})

test_that("get_uniform_vector stops on a missing file", {
    expect_error(
        suppressMessages(get_uniform_vector(tempfile(fileext = ".tsv"))),
        "TSV file not found"
    )
})

test_that("get_mapping_vector maps the first column to the second", {
    tsv <- tempfile(fileext = ".tsv")
    writeLines(c("id\tname", "ENST1\tGapdh", "ENST2\tActb"), tsv)

    map <- suppressMessages(get_mapping_vector(tsv))
    expect_identical(unname(map), c("Gapdh", "Actb"))
    expect_identical(names(map), c("ENST1", "ENST2"))
})

test_that("get_mapping_vector rejects a single-column file", {
    tsv <- tempfile(fileext = ".tsv")
    writeLines(c("ENST1", "ENST2"), tsv)
    expect_error(suppressMessages(get_mapping_vector(tsv)), "at least two columns")
})

test_that("save_object creates the directory, appends .rds and returns the path", {
    out_dir <- file.path(tempfile("dir"), "nested")   # does not exist yet
    path <- suppressMessages(save_object(1:3, out_dir = out_dir, file_name = "obj"))

    expect_identical(path, file.path(out_dir, "obj.rds"))
    expect_true(file.exists(path))
    expect_identical(readRDS(path), 1:3)
})

test_that("save_object does not double the .rds extension", {
    out_dir <- tempfile("dir")
    path <- suppressMessages(save_object("x", out_dir = out_dir, file_name = "keep.rds"))
    expect_identical(basename(path), "keep.rds")
})
