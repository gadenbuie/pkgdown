test_that("both versions of build_site have same arguments", {
  expect_equal(formals(build_site_local), formals(build_site_external))
})

test_that("can build package without any index/readme", {
  pkg <- local_pkgdown_site(test_path("assets/site-empty"))
  expect_no_error(suppressMessages(build_site(pkg, new_process = FALSE)))
})
