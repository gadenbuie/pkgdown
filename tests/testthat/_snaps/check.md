# sitrep complains about BS3

    Code
      pkgdown_sitrep(pkg)
    Message
      -- Sitrep ----------------------------------------------------------------------
      x Bootstrap 3 is deprecated; please switch to Bootstrap 5.
      i Learn more at <https://www.tidyverse.org/blog/2021/12/pkgdown-2-0-0/#bootstrap-5>.
      v URLs ok.
      v Open graph metadata ok.
      v Articles metadata ok.
      v Reference metadata ok.

# sitrep reports all problems

    Code
      pkgdown_sitrep(pkg)
    Message
      -- Sitrep ----------------------------------------------------------------------
      x URLs not ok.
        'DESCRIPTION' URL lacks package url (http://test.org).
        See details in `vignette(pkgdown::metadata)`.
      v Open graph metadata ok.
      v Articles metadata ok.
      x Reference metadata not ok.
        1 topic missing from index: "?".
        Either use `@keywords internal` to drop from index, or
        Edit _pkgdown.yml to fix the problem.

# checks fails on first problem

    Code
      check_pkgdown(pkg)
    Condition
      Error in `check_pkgdown()`:
      ! 'DESCRIPTION' URL lacks package url (http://test.org).
      i See details in `vignette(pkgdown::metadata)`.

# both inform if everything is ok

    Code
      pkgdown_sitrep(pkg)
    Message
      -- Sitrep ----------------------------------------------------------------------
      v URLs ok.
      v Open graph metadata ok.
      v Articles metadata ok.
      v Reference metadata ok.
    Code
      check_pkgdown(pkg)
    Message
      v No problems found.

# check_urls reports problems

    Code
      check_urls(pkg)
    Condition
      Error:
      ! _pkgdown.yml lacks url.
      i See details in `vignette(pkgdown::metadata)`.

---

    Code
      check_urls(pkg)
    Condition
      Error:
      ! 'DESCRIPTION' URL lacks package url (https://testpackage.r-lib.org).
      i See details in `vignette(pkgdown::metadata)`.

