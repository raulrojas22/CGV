library(testthat)

utils_path <- file.path("R", "utils.R")
if (!file.exists(utils_path)) utils_path <- file.path("..", "..", "R", "utils.R")
utils_env <- new.env(parent = globalenv())
sys.source(utils_path, envir = utils_env)

write_twobit_fixture <- function(path, seq_name, sequence, mask_start0 = 0L, mask_size = 0L) {
    sequence <- toupper(sequence)
    chars <- strsplit(sequence, "", fixed = TRUE)[[1L]]
    n_positions <- which(chars == "N")
    n_starts <- integer(0)
    n_sizes <- integer(0)
    if (length(n_positions) > 0L) {
        groups <- cumsum(c(TRUE, diff(n_positions) != 1L))
        runs <- split(n_positions, groups)
        n_starts <- vapply(runs, function(x) min(x) - 1L, integer(1))
        n_sizes <- vapply(runs, length, integer(1))
    }
    packed_chars <- chars
    packed_chars[packed_chars == "N"] <- "T"
    pad <- (4L - length(packed_chars) %% 4L) %% 4L
    if (pad > 0L) packed_chars <- c(packed_chars, rep("T", pad))
    codes <- c(T = 0L, C = 1L, A = 2L, G = 3L)[packed_chars]
    code_matrix <- matrix(as.integer(codes), ncol = 4L, byrow = TRUE)
    packed <- as.raw(
        bitwShiftL(code_matrix[, 1L], 6L) +
            bitwShiftL(code_matrix[, 2L], 4L) +
            bitwShiftL(code_matrix[, 3L], 2L) +
            code_matrix[, 4L]
    )

    name_raw <- charToRaw(seq_name)
    record_offset <- 16L + 1L + length(name_raw) + 4L
    con <- file(path, open = "wb")
    on.exit(close(con), add = TRUE)
    writeBin(as.integer(0x1A412743), con, size = 4L, endian = "little")
    writeBin(as.integer(c(0L, 1L, 0L)), con, size = 4L, endian = "little")
    writeBin(as.raw(length(name_raw)), con)
    writeBin(name_raw, con)
    writeBin(as.integer(record_offset), con, size = 4L, endian = "little")
    writeBin(as.integer(nchar(sequence)), con, size = 4L, endian = "little")
    writeBin(as.integer(length(n_starts)), con, size = 4L, endian = "little")
    if (length(n_starts) > 0L) {
        writeBin(as.integer(n_starts), con, size = 4L, endian = "little")
        writeBin(as.integer(n_sizes), con, size = 4L, endian = "little")
    }
    has_mask <- is.finite(mask_size) && mask_size > 0L
    writeBin(as.integer(if (has_mask) 1L else 0L), con, size = 4L, endian = "little")
    if (has_mask) {
        writeBin(as.integer(mask_start0), con, size = 4L, endian = "little")
        writeBin(as.integer(mask_size), con, size = 4L, endian = "little")
    }
    writeBin(as.integer(0L), con, size = 4L, endian = "little")
    writeBin(packed, con)
    invisible(path)
}

test_that("native 2bit reader preserves bases, N blocks, masks and coordinate slicing", {
    old_cache <- Sys.getenv("CGV_CACHE_DIR", unset = NA_character_)
    on.exit({
        if (is.na(old_cache)) Sys.unsetenv("CGV_CACHE_DIR") else Sys.setenv(CGV_CACHE_DIR = old_cache)
    }, add = TRUE)
    Sys.setenv(CGV_CACHE_DIR = tempfile("cgev-native-twobit-cache-"))
    fixture <- tempfile(fileext = ".2bit")
    expected <- "TCAGTCNNNNAGGCTANNTCAGTCA"
    write_twobit_fixture(fixture, "chrFixture", expected, mask_start0 = 1L, mask_size = 5L)

    idx <- utils_env$read_twobit_native_index(fixture)
    expect_identical(idx$endian, "little")
    expect_identical(idx$seqnames, "chrFixture")
    expect_identical(utils_env$get_twobit_seqnames(fixture), "chrFixture")
    expect_identical(
        utils_env$extract_sequence_from_2bit_native(fixture, "chrFixture", 1L, nchar(expected)),
        expected
    )
    expect_identical(
        utils_env$extract_sequence_from_2bit_native(fixture, "chrFixture", 5L, 18L),
        substr(expected, 5L, 18L)
    )
    expect_identical(
        utils_env$extract_sequence_from_2bit_native(fixture, "chrFixture", 2L, 2L),
        substr(expected, 2L, 2L)
    )
    expect_identical(utils_env$extract_sequence_from_2bit_native(fixture, "missing", 1L, 5L), "")
})

test_that("public 2bit extraction uses the native reader without rtracklayer", {
    old_cache <- Sys.getenv("CGV_CACHE_DIR", unset = NA_character_)
    on.exit({
        if (is.na(old_cache)) Sys.unsetenv("CGV_CACHE_DIR") else Sys.setenv(CGV_CACHE_DIR = old_cache)
    }, add = TRUE)
    Sys.setenv(CGV_CACHE_DIR = tempfile("cgev-native-twobit-cache-"))
    fixture <- tempfile(fileext = ".2bit")
    expected <- "ACGTACGTNNACGT"
    write_twobit_fixture(fixture, "chrNative", expected)
    old <- Sys.getenv("APP_NATIVE_TWOBIT_READER", unset = NA_character_)
    on.exit({
        if (is.na(old)) Sys.unsetenv("APP_NATIVE_TWOBIT_READER") else Sys.setenv(APP_NATIVE_TWOBIT_READER = old)
    }, add = TRUE)
    Sys.setenv(APP_NATIVE_TWOBIT_READER = "1")
    expect_identical(
        utils_env$extract_sequence_from_2bit(fixture, "chrNative", 3L, 12L),
        substr(expected, 3L, 12L)
    )
    expect_false("rtracklayer" %in% loadedNamespaces())
})
