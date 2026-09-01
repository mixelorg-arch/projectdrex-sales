# Ledger — sales & payroll

A single-page tracker for daily sales, employee salaries and expenses.
Served by GitHub Pages from `index.html` at the root of this repository.

* Figures are kept per month; the Month selector filters entries and expenses.
* Data is saved in the browser's `localStorage` under `ledger-data-v1` —
  it lives on the device you use, and is not synced anywhere.
* **Export** writes a JSON backup; **Import** restores one. Since the data is
  per-browser, Export is the only backup that exists.

**This page is publicly reachable.** GitHub Pages sites are served publicly
even when the repository is private, and this page has real figures in it.
`robots.txt` and a `noindex` tag discourage search engines, which is not the
same as access control.

Source of truth for edits: `~/Movies/Work/CLAUDE/SalesTracker/`.
