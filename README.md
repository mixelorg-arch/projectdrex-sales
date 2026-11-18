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

## Attendance

An **Attendance** tab shows, for the month on screen, which day each person
punched in on, their shift times, and a **Days present** tally per person at
the foot.

It is **read only**. The punches live in ProjectDrex AMS, a separate Supabase
project; this project keeps a mirror of them (`salesinv_staff`,
`salesinv_attendance`, filled by `salesinv_pull_attendance()`), and the tab
only reads it. No entry, no date and no figure anybody has typed into the
ledger is written by any of it.

It is deliberately **not** folded into the pay columns of the sales log. The
two rosters do not line up — the clock has `JUSTINE` where the ledger has
`Justin`, and the ledger holds two Arvins — so merging them would credit the
wrong person. Presence is shown under the clock's own names, beside the ledger
rather than inside it.

Run `supabase/attendance.sql` once to open the mirror to ledger members. The
mirror itself is created by `SalesInventory/supabase/attendance.sql`.

