#' Check `_pkgdown.yml`
#'
#' @description
#' This pair of functions checks that your `_pkgdown.yml` is valid without
#' building the whole site. `check_pkgdown()` errors at the first problem;
#' `pkgdown_sitrep()` reports the status of all checks.
#'
#' Currently they check that:
#'
#' * There's a `url` in the pkgdown configuration, which is also recorded
#'   in the `URL` field of the `DESCRIPTION`.
#'
#' * All opengraph metadata is valid.
#'
#' * All reference topics are included in the index.
#'
#' * All articles/vignettes are included in the index.
#
#' @export
#' @inheritParams as_pkgdown
check_pkgdown <- function(pkg = ".") {
  pkg <- as_pkgdown(pkg)

  check_urls(pkg)
  data_open_graph(pkg)
  data_articles_index(pkg)
  data_reference_index(pkg)

  cli::cli_inform(c("v" = "No problems found."))
}

#' @export
#' @rdname check_pkgdown
pkgdown_sitrep <- function(pkg = ".") {
  cli::cli_rule("Sitrep")

  pkg <- as_pkgdown(pkg)
  if (pkg$bs_version == 3) {
    cli::cli_inform(c(
      x = "Bootstrap 3 is deprecated; please switch to Bootstrap 5.",
      i = "Learn more at {.url https://www.tidyverse.org/blog/2021/12/pkgdown-2-0-0/#bootstrap-5}."
    ))
  }

  error_to_sitrep("URLs", check_urls(pkg))
  error_to_sitrep("Open graph metadata", data_open_graph(pkg))
  error_to_sitrep("Articles metadata", data_articles_index(pkg))
  error_to_sitrep("Reference metadata", data_reference_index(pkg))
}

error_to_sitrep <- function(title, code) {
  tryCatch(
    {
      code
      cli::cli_inform(c("v" = "{title} ok."))
    },
    rlang_error = function(e) {
      bullets <- c(cnd_header(e), cnd_body(e))
      cli::cli_inform(c(x = "{title} not ok.", set_names(bullets, " ")))
    }
  )
  invisible()
}

check_urls <- function(pkg = ".", call = caller_env()) {
  pkg <- as_pkgdown(pkg)
  details <- c(i = "See details in {.vignette pkgdown::metadata}.")

  if (identical(pkg$meta, list())) {
    cli::cli_abort(
      c("No {.path _pkgdown.yml} found.", details),
      call = call
    )
  }

  url <- pkg$meta[["url"]]

  if (is.null(url)) {
    cli::cli_abort(
      c("{config_path(pkg)} lacks {.field url}.", details),
      call = call
    )
  } else {
    desc_urls <- pkg$desc$get_urls()
    desc_urls <- sub("/$", "", desc_urls)

    if (!pkg$meta[["url"]] %in% desc_urls) {
      cli::cli_abort(
        c("{.file DESCRIPTION} {.field URL} lacks package url ({url}).", details),
        call = call
      )
    }
  }
}
