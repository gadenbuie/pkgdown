#' Render page with template
#'
#' Each page is composed of four templates: "head", "header", "content", and
#' "footer". Each of these templates is rendered using the `data`, and
#' then assembled into an overall page using the "layout" template.
#'
#' @param pkg Path to package to document.
#' @param name Name of the template (e.g. "home", "vignette", "news")
#' @param data Data for the template.
#'
#'   This is automatically supplemented with three lists:
#'
#'   * `site`: `title` and path to `root`.
#'   * `yaml`: the `template` key from `_pkgdown.yml`.
#'   * `package`: package metadata including `name` and`version`.
#'
#'   See the full contents by running [data_template()].
#' @param path Location to create file; relative to destination directory.
#' @param depth Depth of path relative to base directory.
#' @param quiet If `quiet`, will suppress output messages
#' @export
render_page <- function(pkg = ".", name, data, path, depth = NULL, quiet = FALSE) {
  pkg <- as_pkgdown(pkg)

  if (is.null(depth)) {
    depth <- length(strsplit(path, "/")[[1]]) - 1L
  }

  html <- render_page_html(pkg, name = name, data = data, depth = depth)

  tweak_page(html, name, pkg = pkg)
  if (pkg$bs_version > 3) {
    activate_navbar(html, data$output_file %||% path, pkg)
  }

  rendered <- as.character(html, options = character())
  write_if_different(pkg, rendered, path, quiet = quiet)
}

render_page_html <- function(pkg, name, data = list(), depth = 0L) {
  data <- modify_list(data_template(pkg, depth = depth), data)

  # render template components
  pieces <- c(
    "head",
    "in-header",
    "before-body",
    "navbar",
    "content",
    "footer",
    "after-body",
    if (pkg$bs_version == 3) c("header", "docsearch")
  )

  templates <- purrr::map_chr(pieces, find_template, name = name, pkg = pkg)
  components <- purrr::map(templates, render_template, data = data)
  components <- purrr::set_names(components, pieces)
  components$template <- name
  components$lang <- pkg$lang
  components$translate <- data$translate

  # render complete layout
  template <- find_template("layout", name, pkg = pkg)
  rendered <- render_template(template, components)

  # Strip trailing whitespace
  rendered <- gsub("\\s+\n", "\n", rendered, perl = TRUE)

  xml2::read_html(rendered, encoding = "UTF-8")
}

#' @export
#' @rdname render_page
data_template <- function(pkg = ".", depth = 0L) {
  pkg <- as_pkgdown(pkg)
  out <- list()

  # Basic metadata
  out$package <- list(
    name = pkg$package,
    version = as.character(pkg$version)
  )
  if (has_logo(pkg)) {
    out$logo <- list(src = logo_path(pkg, depth = depth))
  }
  out$site <- list(
    root = up_path(depth),
    title = config_pluck_string(pkg, "title", default = pkg$package)
  )
  out$year <- strftime(Sys.time(), "%Y")

  # Language and translations
  out$lang <- pkg$lang
  out$translate <- list(
    skip = tr_("Skip to contents"),
    toggle_nav = tr_("Toggle navigation"),
    on_this_page = tr_("On this page"),
    source = tr_("Source"),
    abstract = tr_("Abstract"),
    authors = tr_("Authors"),
    version = tr_("Version"),
    examples = tr_("Examples"),
    citation = tr_("Citation"),
    author_details = tr_("Additional details"),
    toc = tr_("Table of contents"),
    site_nav = tr_("Site navigation")
  )

  # Components that mostly end up in the <head>
  out$has_favicons <- has_favicons(pkg)
  out$opengraph <- data_open_graph(pkg)
  out$extra <- list(
    css = path_first_existing(pkg$src_path, "pkgdown", "extra.css"),
    js = path_first_existing(pkg$src_path, "pkgdown", "extra.js")
  )
  out$includes <- config_pluck(pkg, "template.includes")
  out$yaml <- config_pluck(pkg, "template.params")
  # Force inclusion so you can reliably refer to objects inside yaml
  # in the mustache templates
  out$yaml$.present <- TRUE
  if (pkg$bs_version > 3) {
    out$headdeps <- data_deps(pkg = pkg, depth = depth)
  }

  # Development settings; tooltip needs to be generated at render time
  out$development <- pkg$development
  out$development$version_tooltip <- version_tooltip(pkg$development$mode)

  out$navbar <- data_navbar(pkg, depth = depth)
  out$footer <- data_footer(pkg)

  print_yaml(out)
}

data_open_graph <- function(pkg = ".", call = caller_env()) {
  pkg <- as_pkgdown(pkg)
  og <- config_pluck_list(pkg, "template.opengraph", default = list())
  og <- check_open_graph(og, pkgdown_config_path(pkg) %||% "_pkgdown.yml", call = call)
  if (is.null(og$image) && !is.null(find_logo(pkg$src_path))) {
    og$image <- list(src = path_file(find_logo(pkg$src_path)))
  }
  if (!is.null(og$image) && !grepl("^http", og$image$src)) {
    site_url <- config_pluck(pkg, "url", default = "/")
    if (!grepl("/$", site_url)) {
      site_url <- paste0(site_url, "/")
    }
    og$image$src <- gsub("^man/figures/", "reference/figures/", og$image$src)
    og$image$src <- paste0(site_url, og$image$src)
  }

  og$twitter$creator <- og$twitter$creator %||% og$twitter$site
  og$twitter$site <- og$twitter$site %||% og$twitter$creator
  og
}

check_open_graph <- function(og, path, call = caller_env()) {
  if (is.null(og)) {
    return()
  }

  is_yaml <- path_ext(path) %in% c("yml", "yaml")
  base_path <- if (is_yaml) "template.opengraph" else "opengraph"

  check_open_graph_list(
    og,
    file_path = path,
    error_path = base_path,
    error_call = call
  )

  supported_fields <- c("image", "twitter")
  unsupported_fields <- setdiff(names(og), supported_fields)
  if (length(unsupported_fields)) {
    cli::cli_warn(
      "{.file {path}}: Unsupported {.field {base_path}} {cli::qty(unsupported_fields)} field{?s}: {.val {unsupported_fields}}.",
      call = call
    )
  }
  check_open_graph_list(
    og$twitter,
    file_path = path,
    error_path = paste0(base_path, ".twitter"),
    error_call = call
  )
  if (!is.null(og$twitter) && is.null(og$twitter$creator) && is.null(og$twitter$site)) {
    cli::cli_abort(
      "{.file {path}}: {.field opengraph.twitter} must include either {.field creator} or {.field site}.",
      call = call
    )
  }
  check_open_graph_list(
    og$image,
    file_path = path,
    error_path = paste0(base_path, ".image"),
    error_call = call
  )
  og[intersect(supported_fields, names(og))]
}

render_template <- function(path, data) {
  template <- read_file(path)
  if (length(template) == 0)
    return("")

  whisker::whisker.render(template, data)
}

check_open_graph_list <- function(x,
                                  file_path,
                                  error_path,
                                  error_call = caller_env()) {
  if (is.list(x) || is.null(x)) {
    return()
  }
  not <- obj_type_friendly(x)
  cli::cli_abort(
    "{.file {file_path}}: {.field {error_path}} must be a list, not {not}.",
    call = error_call
  )
}

write_if_different <- function(pkg, contents, path, quiet = FALSE, check = TRUE) {
  # Almost all uses are relative to destination, except for rmarkdown templates
  full_path <- path_abs(path, start = pkg$dst_path)

  if (check && !made_by_pkgdown(full_path)) {
    if (!quiet) {
      cli::cli_inform("Skipping {.file {path}}: not generated by pkgdown")
    }
    return(FALSE)
  }

  if (same_contents(full_path, contents)) {
    # touching the file to update its modification time
    # which is important for proper lazy behavior
    file_touch(full_path)
    return(FALSE)
  }

  if (!quiet) {
    writing_file(path_rel(full_path, pkg$dst_path), path)
  }

  write_lines(contents, path = full_path)
  TRUE
}

same_contents <- function(path, contents) {
  if (!file_exists(path))
    return(FALSE)

  new_hash <- digest::digest(contents, serialize = FALSE)

  cur_contents <- paste0(read_lines(path), collapse = "\n")
  cur_hash <-  digest::digest(cur_contents, serialize = FALSE)

  identical(new_hash, cur_hash)
}

file_digest <- function(path) {
  if (file_exists(path)) {
    digest::digest(file = path, algo = "xxhash64")
  } else {
    "MISSING"
  }
}


made_by_pkgdown <- function(path) {
  if (!file_exists(path)) return(TRUE)

  first <- paste(read_lines(path, n = 2), collapse = "\n")
  check_made_by(first)
}

check_made_by <- function(first) {
  if (length(first) == 0L) return(FALSE)
  grepl("<!-- Generated by pkgdown", first, fixed = TRUE)
}
