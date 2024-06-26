test_that("docsearch.json and sitemap.xml are valid for BS 3 site", {
  pkg <- local_pkgdown_site(test_path("assets/search-site"))

  suppressMessages(build_site(pkg, new_process = FALSE))
  json <- path(pkg$dst_path, "docsearch.json")
  expect_true(jsonlite::validate(read_lines(json)))

  xml <- path(pkg$dst_path, "sitemap.xml")
  schema <- xml2::read_xml(path(pkg$src_path, "sitemaps-schema-0.9.xsd"))
  expect_true(xml2::xml_validate(xml2::read_xml(xml), schema))
})

test_that("build_search() builds the expected search.json with an URL", {
  pkg <- local_pkgdown_site(test_path("assets/news"), '
    url: https://example.com
    template:
      bootstrap: 5
    news:
      cran_dates: false
    development:
      mode: devel
  ')

  suppressMessages(init_site(pkg))
  suppressMessages(build_news(pkg))
  suppressMessages(build_home(pkg))
  suppressMessages(build_sitemap(pkg))

  json_path <- withr::local_tempfile()
  jsonlite::write_json(build_search_index(pkg), json_path, pretty = TRUE)
  expect_snapshot_file(json_path, "search.json")
})

test_that("build_search() builds the expected search.json with no URL", {
  pkg <- local_pkgdown_site(test_path("assets/news"), '
    template:
      bootstrap: 5
    news:
      cran_dates: false
    development:
      mode: devel
  ')

  suppressMessages(init_site(pkg))
  suppressMessages(build_news(pkg))
  suppressMessages(build_home(pkg))
  suppressMessages(build_sitemap(pkg))

  json_path <- withr::local_tempfile()
  jsonlite::write_json(build_search_index(pkg), json_path, pretty = TRUE)
  expect_snapshot_file(json_path, "search-no-url.json")
})

test_that("url_node gives informative error", {
  expect_snapshot(url_node("<"), error = TRUE)
})
