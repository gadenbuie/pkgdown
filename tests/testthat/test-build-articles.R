test_that("can recognise intro variants", {
  expect_true(article_is_intro("package", "package"))
  expect_true(article_is_intro("articles/package", "package"))
  expect_true(article_is_intro("pack-age", "pack.age"))
  expect_true(article_is_intro("articles/pack-age", "pack.age"))
})

test_that("image links relative to output", {
  # weird path differences that I don't have the energy to dig into
  skip_on_cran()
  pkg <- local_pkgdown_site(test_path("assets/articles-images"))

  suppressMessages(init_site(pkg))
  suppressMessages(copy_figures(pkg))
  suppressMessages(build_article("kitten", pkg))

  html <- xml2::read_html(path(pkg$dst_path, "articles", "kitten.html"))
  src <- xpath_attr(html, "//main//img", "src")

  expect_equal(src, c(
    # knitr::include_graphics()
    "../reference/figures/kitten.jpg",
    "another-kitten.jpg",
    # rmarkdown image
    "../reference/figures/kitten.jpg",
    "another-kitten.jpg",
    # magick::image_read()
    "kitten_files/figure-html/magick-1.png",
    # figure
    "kitten_files/figure-html/plot-1.jpg"
  ))

  # And files aren't copied
  expect_false(dir_exists(path(pkg$dst_path, "man")))
})

test_that("warns about missing images", {
  # Added in #2509: I can't figure out why this is necessary :(
  skip_on_covr()

  pkg <- local_pkgdown_site(test_path("assets/bad-images"))
  expect_snapshot(build_articles(pkg))
})

test_that("warns about missing alt-text", {
  pkg <- local_pkgdown_site(test_path("assets/missing-alt"))
  expect_snapshot(build_article("missing-images", pkg))
})

test_that("articles don't include header-attrs.js script", {
  pkg <- local_pkgdown_site(test_path("assets/articles"))
  suppressMessages(init_site(pkg))

  suppressMessages(path <- build_article("standard", pkg))

  html <- xml2::read_html(path)
  js <- xpath_attr(html, ".//body//script", "src")
  # included for pandoc 2.7.3 - 2.9.2.1 improve accessibility
  js <- js[path_file(js) != "empty-anchor.js"]
  expect_equal(js, character())
})

test_that("can build article that uses html_vignette", {
  pkg <- local_pkgdown_site(test_path("assets/articles"))
  suppressMessages(init_site(pkg))

  # theme is not set since html_vignette doesn't support it
  expect_snapshot(expect_error(build_article("html-vignette", pkg), NA))
})

test_that("can override html_document() options", {
  pkg <- local_pkgdown_site(test_path("assets/articles"))
  suppressMessages(init_site(pkg))
  suppressMessages(path <- build_article("html-document", pkg))

  # Check that number_sections is respected
  html <- xml2::read_html(path)
  expect_equal(xpath_text(html, ".//h2//span"), c("1", "2"))

  # But title isn't affected
  expect_equal(xpath_text(html, ".//h1"), "html_document + as_is")

  # And no links or scripts are inlined
  expect_equal(xpath_length(html, ".//body//link"), 0)
  expect_equal(xpath_length(html, ".//body//script"), 0)
})

test_that("html widgets get needed css/js", {
  pkg <- local_pkgdown_site(test_path("assets/articles"))
  suppressMessages(init_site(pkg))
  suppressMessages(path <- build_article("widget", pkg))

  html <- xml2::read_html(path)
  css <- xpath_attr(html, ".//body//link", "href")
  js <- xpath_attr(html, ".//body//script", "src")

  expect_true("diffviewer.css" %in% path_file(css))
  expect_true("diffviewer.js" %in% path_file(js))
})

test_that("can override options with _output.yml", {
  pkg <- local_pkgdown_site(test_path("assets/articles"))
  suppressMessages(init_site(pkg))
  suppressMessages(path <- build_article("html-document", pkg))

  # Check that number_sections is respected
  html <- xml2::read_html(path)
  expect_equal(xpath_text(html, ".//h2//span"), c("1", "2"))
})

test_that("can set width", {
  pkg <- local_pkgdown_site(test_path("assets/articles"), "
    code:
      width: 50
  ")
  suppressMessages(init_site(pkg))

  suppressMessages(path <- build_article("width", pkg))
  html <- xml2::read_html(path)
  expect_equal(xpath_text(html, ".//pre")[[2]], "## [1] 50")
})

test_that("bad width gives nice error", {
  pkg <- local_pkgdown_site(meta = list(code = list(width = "abc")))
  expect_snapshot(build_rmarkdown_format(pkg, "article"), error = TRUE)
})

test_that("validates articles yaml", {
  data_articles_index_ <- function(x) {
    pkg <- local_pkgdown_site(meta = list(articles = x))
    data_articles_index(pkg)
  }

  expect_snapshot(error = TRUE, {
    data_articles_index_(1)
    data_articles_index_(list(1))
    data_articles_index_(list(list(title = 1)))
    data_articles_index_(list(list(title = "a\n\nb")))
    data_articles_index_(list(list(title = "a", contents = 1)))
  })
})

test_that("finds external resources referenced by R code in the article html", {
  # weird path differences that I don't have the energy to dig into
  skip_on_cran()
  pkg <- local_pkgdown_site(test_path("assets", "articles-resources"))

  suppressMessages(path <- build_article("resources", pkg))

  # ensure that we the HTML references `<img src="external.png" />` directly
  expect_equal(
    xpath_attr(xml2::read_html(path), ".//img", "src"),
    "external.png"
  )

  # expect that `external.png` was copied to the rendered article directory
  expect_true(
    file_exists(path(path_dir(path), "external.png"))
  )
})

test_that("BS5 article laid out correctly with and without TOC", {
  pkg <- local_pkgdown_site(test_path("assets/articles"), "
    template:
      bootstrap: 5
  ")

  suppressMessages(init_site(pkg))
  suppressMessages(toc_true_path <- build_article("standard", pkg))
  suppressMessages(toc_false_path <- build_article("toc-false", pkg))

  toc_true <- xml2::read_html(toc_true_path)
  toc_false <- xml2::read_html(toc_false_path)

  # Always has class col-md-9
  expect_equal(xpath_attr(toc_false, ".//main", "class"), "col-md-9")
  expect_equal(xpath_attr(toc_true, ".//main", "class"), "col-md-9")

  # The no sidebar without toc
  expect_equal(xpath_length(toc_true, ".//aside"), 1)
  expect_equal(xpath_length(toc_false, ".//aside"), 0)
})

test_that("articles in vignettes/articles/ are unnested into articles/", {
  # weird path differences that I don't have the energy to dig into
  skip_on_cran()

  pkg <- local_pkgdown_site(test_path("assets/articles"))
  suppressMessages(init_site(pkg))
  suppressMessages(path <- build_article("articles/nested", pkg))

  expect_equal(
    path_real(path),
    path_real(path(pkg$dst_path, "articles", "nested.html"))
  )

  # Check automatic redirect from articles/articles/foo.html -> articles/foo.html
  pkg$meta$url <- "https://example.com"
  expect_snapshot(build_redirects(pkg))

  # Check that the redirect file exists in <dst>/articles/articles/
  redirect_path <- path(pkg$dst_path, "articles", "articles", "nested.html")
  expect_true(file_exists(redirect_path))

  # Check that we redirect to correct location
  html <- xml2::read_html(redirect_path)
  expect_match(
    xpath_attr(html, ".//meta[@http-equiv = 'refresh']", "content"),
    "https://example.com/articles/nested.html",
    fixed = TRUE
  )
})

test_that("pkgdown deps are included only once in articles", {
  pkg <- local_pkgdown_site(test_path("assets/articles"), "
    template:
      bootstrap: 5
  ")

  suppressMessages(init_site(pkg))
  suppressMessages(path <- build_article("html-deps", pkg))

  html <- xml2::read_html(path)

  # jquery is only loaded once, even though it's also added by code in the article
  expect_equal(xpath_length(html, ".//script[(@src and contains(@src, '/jquery'))]"), 1)

  # same for bootstrap js and css
  str_subset_bootstrap <- function(x) {
    bs_rgx <- "bootstrap-[\\d.]+" # ex: bootstrap-5.1.0 not bootstrap-toc,
    grep(bs_rgx, x, value = TRUE, perl = TRUE)
  }
  bs_js_src <- str_subset_bootstrap(
    xpath_attr(html, ".//script[(@src and contains(@src, '/bootstrap'))]", "src")
  )
  expect_length(bs_js_src, 1)

  bs_css_href <- str_subset_bootstrap(
    xpath_attr(html, ".//link[(@href and contains(@href, '/bootstrap'))]", "href")
  )
  expect_length(bs_css_href, 1)
})

test_that("warns about articles missing from index", {
  pkg <- local_pkgdown_site()
  write_lines(path = path(pkg$src_path, "_pkgdown.yml"), "
    articles:
    - title: External
      contents: [a, b]
  ")
  dir_create(path(pkg$src_path, "vignettes"))
  file_create(path(pkg$src_path, "vignettes", paste0(letters[1:3], ".Rmd")))
  pkg <- as_pkgdown(pkg$src_path)

  expect_snapshot(. <- data_articles_index(pkg), error = TRUE)
})

test_that("internal articles aren't included and don't trigger warning", {
  pkg <- local_pkgdown_site()
  write_lines(path = path(pkg$src_path, "_pkgdown.yml"), "
    articles:
    - title: External
      contents: [a, b]
    - title: internal
      contents: c
  ")
  dir_create(path(pkg$src_path, "vignettes"))
  file_create(path(pkg$src_path, "vignettes", paste0(letters[1:3], ".Rmd")))
  pkg <- as_pkgdown(pkg$src_path)

  expect_no_error(index <- data_articles_index(pkg))
  expect_length(index$sections, 1)
  expect_length(index$sections[[1]]$contents, 2)
})

test_that("default template includes all articles", {
  pkg <- local_pkgdown_site()
  dir_create(path(pkg$src_path, "vignettes"))
  file_create(path(pkg$src_path, "vignettes", "a.Rmd"))
  pkg <- as_pkgdown(pkg$src_path)

  expect_equal(default_articles_index(pkg)[[1]]$contents, "a")
})

test_that("check doesn't include getting started vignette", {
  pkg <- local_pkgdown_site(test_path("assets/articles-resources"))
  getting_started <- path(pkg$src_path, "vignettes", paste0(pkg$package, ".Rmd"))
  file_create(getting_started)
  withr::defer(file_delete(getting_started))

  pkg <- local_pkgdown_site(test_path("assets/articles-resources"), meta = "
    articles:
     - title: Title
       contents: resources
  ")

  expect_error(data_articles_index(pkg), NA)
})

test_that("titles are escaped when needed", {
  pkg <- local_pkgdown_site(test_path("assets/articles"))
  suppressMessages(init_site(pkg))
  suppressMessages(build_article(pkg = pkg, name = "needs-escape"))

  html <- xml2::read_html(path(pkg$dst_path, "articles/needs-escape.html"))
  expect_equal(xpath_text(html, "//title", trim = TRUE), "a <-> b • testpackage")
  expect_equal(xpath_text(html, "//h1", trim = TRUE), "a <-> b")
})


test_that("output is reproducible by default, i.e. 'seed' is respected", {
  pkg <- local_pkgdown_site(test_path("assets/articles"))
  suppressMessages(init_site(pkg))
  suppressMessages(build_article(pkg = pkg, name = "random"))

  output <- xml2::read_html(path(pkg$dst_path, "articles/random.html")) %>%
    rvest::html_node("main > pre") %>%
    rvest::html_text() %>%
    # replace line feeds with whitespace to make output platform independent
    gsub("\r", "", .)

  expect_snapshot(cat(output))
})

test_that("reports on bad open graph meta-data", {
  pkg <- local_pkgdown_site(test_path("assets/articles"))
  suppressMessages(init_site(pkg))
  expect_snapshot(build_article(pkg = pkg, name = "bad-opengraph"), error = TRUE)
})
