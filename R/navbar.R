data_navbar <- function(pkg = ".", depth = 0L) {
  pkg <- as_pkgdown(pkg)

  navbar <- config_pluck(pkg, "navbar")

  style <- navbar_style(
    navbar = navbar,
    theme = get_bslib_theme(pkg),
    bs_version = pkg$bs_version
  )

  links <- navbar_links(pkg, depth = depth)

  c(style, links)
}

# Default navbar ----------------------------------------------------------

navbar_style <- function(navbar = list(), theme = "_default", bs_version = 3) {
  if (bs_version == 3) {
    list(type = navbar$type %||% "default")
  } else {
    # bg is usually light, dark, or primary, but can use any .bg-*
    bg <- navbar$bg %||% bootswatch_bg[[theme]] %||% "light"
    type <- navbar$type %||% if (bg == "light") "light" else "dark"

    list(bg = bg, type = type)
  }
}

navbar_structure <- function() {
  print_yaml(list(
    left = c("intro", "reference", "articles", "tutorials", "news"),
    right = c("search", "github")
  ))
}

navbar_links <- function(pkg, depth = 0L) {
  # Combine default components with user supplied
  components <- modify_list(
    navbar_components(pkg),
    config_pluck(pkg, "navbar.components")
  )

  # Combine default structure with user supplied
  # (must preserve NULLs in yaml to mean display nothing)
  pkg$meta$navbar$structure <- modify_list(
    navbar_structure(),
    config_pluck(pkg, "navbar.structure")
  )
  right_comp <- intersect(
    config_pluck_character(pkg, "navbar.structure.right"),
    names(components)
  )
  left_comp <- intersect(
    config_pluck_character(pkg, "navbar.structure.left"),
    names(components)
  )
  # Backward compatibility
  left <- config_pluck(pkg, "navbar.left") %||% components[left_comp]
  right <- config_pluck(pkg, "navbar.right") %||% components[right_comp]

  list(
    left = render_navbar_links(
      left,
      depth = depth,
      pkg = pkg,
      side = "left"
    ),
    right = render_navbar_links(
      right,
      depth = depth,
      pkg = pkg,
      side = "right"
    )
  )
}

render_navbar_links <- function(x, depth = 0L, pkg, side = c("left", "right")) {
  if (!is.list(x)) {
    config_abort(
      pkg,
      c(
        "{.field navbar} is incorrectly specified.",
        i = "See details in {.vignette pkgdown::customise}."
      ),
      call = quote(data_template())
    )
  }
  check_number_whole(depth, min = 0)
  side <- arg_match(side)

  tweak <- function(x) {
    if (!is.null(x$menu)) {
      x$menu <- lapply(x$menu, tweak)
      x
    } else if (!is.null(x$href) && !grepl("://", x$href, fixed = TRUE)) {
      x$href <- paste0(up_path(depth), x$href)
      x
    } else {
      x
    }
  }
  if (depth != 0L) {
    x <- lapply(x, tweak)
  }

  if (pkg$bs_version == 3) {
    rmarkdown::navbar_links_html(x)
  } else {
    navbar_html_list(x, path_depth = depth, side = side)
  }
}

# Components --------------------------------------------------------------

navbar_components <- function(pkg = ".") {
  pkg <- as_pkgdown(pkg)

  menu <- list()
  menu$reference <- menu_link(tr_("Reference"), "reference/index.html")

  # in BS3, search is hardcoded in the template
  if (pkg$bs_version == 5) {
    menu$search <- menu_search()
  }

  if (!is.null(pkg$tutorials)) {
    menu$tutorials <- menu_submenu(
      tr_("Tutorials"),
      menu_links(pkg$tutorials$title, pkg$tutorials$file_out)
    )
  }
  menu$news <- navbar_news(pkg)

  menu$github <- switch(
    repo_type(pkg),
    github = menu_icon("fab fa-github fa-lg", repo_home(pkg), "GitHub"),
    gitlab = menu_icon("fab fa-gitlab fa-lg", repo_home(pkg), "GitLab"),
    NULL
  )

  menu <- c(menu, navbar_articles(pkg))

  print_yaml(menu)
}

navbar_articles <- function(pkg = ".") {
  pkg <- as_pkgdown(pkg)

  menu <- list()

  vignettes <- pkg$vignettes
  pkg_intro <- article_is_intro(vignettes$name, pkg$package)
  if (any(pkg_intro)) {
    intro <- vignettes[pkg_intro, , drop = FALSE]

    menu$intro <- menu_link(tr_("Get started"), intro$file_out)
  }

  if (!has_name(pkg$meta, "articles")) {
    vignettes <- vignettes[!pkg_intro, , drop = FALSE]
    menu$articles <- menu_submenu(
      tr_("Articles"),
      menu_links(vignettes$title, vignettes$file_out)
    )
  } else {
    articles <- config_pluck(pkg, "articles")

    navbar <- purrr::keep(articles, ~ has_name(.x, "navbar"))
    if (length(navbar) == 0) {
      # No articles to be included in navbar so just link to index
      menu$articles <- menu_link(tr_("Articles"), "articles/index.html")
    } else {
      sections <- lapply(navbar, function(section) {
        vig <- pkg$vignettes[select_vignettes(section$contents, pkg$vignettes), , drop = FALSE]
        vig <- vig[vig$name != pkg$package, , drop = FALSE]
        c(
          if (!is.null(section$navbar)) list(menu_separator(), menu_heading(section$navbar)),
          menu_links(vig$title, vig$file_out)
        )
      })
      children <- unlist(sections, recursive = FALSE, use.names = FALSE)

      if (length(navbar) != length(articles)) {
        children <- c(
          children,
          list(
            menu_separator(),
            menu_link(tr_("More articles..."), "articles/index.html")
          )
        )
      }
      menu$articles <- menu_submenu(tr_("Articles"), children)
    }
  }
  print_yaml(menu)
}

# Testing helpers ---------------------------------------------------------
# Simulate minimal package structure so we can more easily test

pkg_navbar <- function(meta = NULL, vignettes = pkg_navbar_vignettes(),
                       github_url = NULL) {
  structure(
    list(
      package = "test",
      src_path = file_temp(),
      meta = meta,
      vignettes = vignettes,
      repo = list(url = list(home = github_url)),
      bs_version = 5
    ),
    class = "pkgdown"
  )
}

pkg_navbar_vignettes <- function(name = character(),
                                 title = NULL,
                                 file_out = NULL) {
  title <- title %||% paste0("Title ", name)
  file_out <- file_out %||% paste0(name, ".html")

  tibble::tibble(name = name, title = title, file_out)
}


# bootswatch defaults -----------------------------------------------------

# Scraped from bootswatch preivews, see code in
# <https://github.com/r-lib/pkgdown/issues/1758>
bootswatch_bg <- list(
  "_default" = "light",
  cerulean = "primary",
  cosmo = "primary",
  cyborg = "dark",
  darkly = "primary",
  flatly = "primary",
  journal = "light",
  litera = "light",
  lumen = "light",
  lux = "light",
  materia = "primary",
  minty = "primary",
  morph = "primary",
  pulse = "primary",
  quartz = "primary",
  sandstone = "primary",
  simplex = "light",
  sketchy = "light",
  slate = "primary",
  solar = "dark",
  spacelab = "light",
  superhero = "dark",
  united = "primary",
  vapor = "primary",
  yeti = "primary",
  zephyr = "primary"
)
