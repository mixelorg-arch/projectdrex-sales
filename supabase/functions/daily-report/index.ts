// Ledger — daily report by email.
//
// Builds a PDF for a period and sends it with Resend. Invoked by pg_cron at
// 09:00 UTC, which is 17:00 in Manila (the Philippines has no daylight saving,
// so this is 5pm all year).
//
// Secrets required (Dashboard → Edge Functions → Secrets):
//   RESEND_API_KEY   from resend.com
//   REPORT_FROM      verified sender, e.g. "Ledger <ledger@yourdomain.com>"
//   REPORT_TO        projectdrexxx@gmail.com
//   REPORT_OWNER     your auth user id (Dashboard → Authentication → Users)
//   CRON_SECRET      any long random string; also sent by the cron job
//
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { PDFDocument, StandardFonts, rgb } from "https://esm.sh/pdf-lib@1.17.1";

const TZ = "Asia/Manila";
const peso = (n: number) =>
  "PHP " + Number(n || 0).toLocaleString("en-PH", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/** Today's date in Manila as YYYY-MM-DD, regardless of where this runs. */
function manilaToday(): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit",
  }).format(new Date());
}
function addDays(d: string, n: number): string {
  const dt = new Date(d + "T00:00:00Z");
  dt.setUTCDate(dt.getUTCDate() + n);
  return dt.toISOString().slice(0, 10);
}
/** Monday-start week containing `d`. */
function weekStart(d: string): string {
  const dt = new Date(d + "T00:00:00Z");
  return addDays(d, -((dt.getUTCDay() + 6) % 7));
}
function rangeFor(scope: string, anchor: string): [string, string, string] {
  if (scope === "week") {
    const s = weekStart(anchor);
    return [s, addDays(s, 6), `Week of ${s} to ${addDays(s, 6)}`];
  }
  if (scope === "month") {
    const s = anchor.slice(0, 7) + "-01";
    const e = addDays(new Date(Date.UTC(+s.slice(0,4), +s.slice(5,7), 1)).toISOString().slice(0,10), -1);
    return [s, e, `Month of ${anchor.slice(0, 7)}`];
  }
  return [anchor, anchor, anchor];
}

type Entry = {
  date: string; team_sales: number; pay: Record<string, number>;
  incentive: number; paid: boolean; remarks: string;
};

async function buildPdf(
  title: string, period: string, entries: Entry[],
  names: Record<string, string>, expenses: { name: string; amount: number; paid: boolean }[],
): Promise<Uint8Array> {
  const pdf = await PDFDocument.create();
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const bold = await pdf.embedFont(StandardFonts.HelveticaBold);

  let page = pdf.addPage([595.28, 841.89]); // A4 portrait
  const M = 40;
  let y = 801;
  const ink = rgb(0.05, 0.04, 0.03);
  const dim = rgb(0.42, 0.4, 0.39);

  const text = (s: string, x: number, size = 9, f = font, color = ink) =>
    page.drawText(s, { x, y, size, font: f, color });
  const right = (s: string, xEnd: number, size = 9, f = font, color = ink) =>
    page.drawText(s, { x: xEnd - f.widthOfTextAtSize(s, size), y, size, font: f, color });
  const rule = (w = 515, color = rgb(0.85, 0.84, 0.83)) =>
    page.drawRectangle({ x: M, y: y - 3, width: w, height: 0.7, color });
  const newPageIfNeeded = (need = 24) => {
    if (y - need < M) { page = pdf.addPage([595.28, 841.89]); y = 801; }
  };

  text(title, M, 16, bold); y -= 16;
  text(period, M, 9, font, dim); y -= 22;

  // Which people actually appear in this period
  const ids = [...new Set(entries.flatMap((e) => Object.keys(e.pay || {})))];
  const cols = ids.map((id) => ({ id, name: names[id] ?? "Removed" }));

  // Column geometry
  const xDate = M, xSales = 150;
  const payW = cols.length ? Math.min(70, 250 / Math.max(cols.length, 1)) : 0;
  const xPay = cols.map((_, i) => 150 + 62 + i * payW);
  const xInc = 150 + 62 + cols.length * payW + 52;
  const xSal = xInc + 62;

  const header = () => {
    text("DATE", xDate, 7.5, bold, dim);
    right("TEAM SALES", xSales + 62, 7.5, bold, dim);
    cols.forEach((c, i) => right(c.name.toUpperCase().slice(0, 9), xPay[i] + payW, 7.5, bold, dim));
    right("INC/OT", xInc + 52, 7.5, bold, dim);
    right("SALARY", xSal + 52, 7.5, bold, dim);
    y -= 5; rule(515, ink); y -= 12;
  };
  header();

  let tSales = 0, tSal = 0, tInc = 0;
  const perPerson: Record<string, number> = {};

  if (entries.length === 0) {
    text("No entries recorded for this period.", M, 9, font, dim); y -= 16;
  }

  for (const e of entries) {
    newPageIfNeeded(30);
    const payTotal = Object.values(e.pay || {}).reduce((s, v) => s + Number(v || 0), 0);
    const salary = payTotal + Number(e.incentive || 0);
    tSales += Number(e.team_sales || 0); tSal += salary; tInc += Number(e.incentive || 0);

    text(e.date.slice(5), xDate, 8.5);
    right(peso(e.team_sales), xSales + 62, 8.5);
    cols.forEach((c, i) => {
      const has = e.pay && c.id in e.pay;
      right(has ? peso(e.pay[c.id]) : "-", xPay[i] + payW, 8.5);
      if (has) perPerson[c.id] = (perPerson[c.id] || 0) + Number(e.pay[c.id]);
    });
    right(e.incentive ? peso(e.incentive) : "-", xInc + 52, 8.5);
    right(peso(salary), xSal + 52, 8.5);
    y -= 4; rule(); y -= 12;
  }

  if (entries.length) {
    newPageIfNeeded(30);
    y -= 2;
    text("Total", xDate, 8.5, bold);
    right(peso(tSales), xSales + 62, 8.5, bold);
    cols.forEach((c, i) => right(peso(perPerson[c.id] || 0), xPay[i] + payW, 8.5, bold));
    right(peso(tInc), xInc + 52, 8.5, bold);
    right(peso(tSal), xSal + 52, 8.5, bold);
    y -= 24;
  }

  const totalExp = expenses.reduce((s, e) => s + Number(e.amount || 0), 0);
  if (expenses.length) {
    newPageIfNeeded(60);
    text("Expenses", M, 11, bold); y -= 14;
    for (const e of expenses) {
      newPageIfNeeded(20);
      text(e.name, M, 8.5);
      right(peso(e.amount), 300, 8.5);
      text(e.paid ? "Paid" : "Unpaid", 320, 8.5, font, dim);
      y -= 4; rule(280); y -= 12;
    }
    y -= 6;
    text("Total expenses", M, 8.5, bold); right(peso(totalExp), 300, 8.5, bold); y -= 22;
  }

  newPageIfNeeded(70);
  text("Summary", M, 11, bold); y -= 16;
  const line = (label: string, val: number, strong = false) => {
    text(label, M, 9, strong ? bold : font);
    right(peso(val), 300, 9, strong ? bold : font);
    y -= 14;
  };
  line("Total sales", tSales);
  line("Salaries", tSal);
  if (expenses.length) line("Expenses", totalExp);
  line("Net income", tSales - tSal - totalExp, true);

  y -= 14;
  text(`Generated ${new Date().toLocaleString("en-PH", { timeZone: TZ })} - Ledger`, M, 7.5, font, dim);

  return await pdf.save();
}

Deno.serve(async (req) => {
  // Fail closed: this URL is publicly reachable, so refuse to run at all
  // unless CRON_SECRET is configured and matches.
  const secret = Deno.env.get("CRON_SECRET");
  if (!secret || req.headers.get("x-cron-secret") !== secret) {
    return new Response("forbidden", { status: 403 });
  }

  const url = new URL(req.url);
  const scope = url.searchParams.get("scope") ?? "day";
  const anchor = url.searchParams.get("date") ?? manilaToday();
  const owner = Deno.env.get("REPORT_OWNER")!;
  const [from, to, period] = rangeFor(scope, anchor);

  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const [{ data: entries }, { data: people }, { data: expenses }] = await Promise.all([
    db.from("entries").select("*").eq("owner", owner).gte("date", from).lte("date", to).order("date"),
    db.from("employees").select("*").eq("owner", owner),
    scope === "month"
      ? db.from("expenses").select("*").eq("owner", owner).eq("month", anchor.slice(0, 7))
      : Promise.resolve({ data: [] as never[] }),
  ]);

  const names: Record<string, string> = {};
  (people ?? []).forEach((p: { id: string; name: string }) => { names[p.id] = p.name; });

  const titles: Record<string, string> = { day: "Daily report", week: "Weekly report", month: "Monthly report" };
  const bytes = await buildPdf(
    `Ledger - ${titles[scope] ?? "Report"}`, period,
    (entries ?? []) as Entry[], names, (expenses ?? []) as never[],
  );

  let binary = "";
  bytes.forEach((b) => { binary += String.fromCharCode(b); });
  const base64 = btoa(binary);

  const sales = (entries ?? []).reduce((s: number, e: Entry) => s + Number(e.team_sales || 0), 0);

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: Deno.env.get("REPORT_FROM"),
      to: [Deno.env.get("REPORT_TO")],
      subject: `Ledger - ${titles[scope] ?? "Report"} - ${period}`,
      text: `Attached is the ${scope} report for ${period}.\n\n`
          + `Entries: ${(entries ?? []).length}\nTotal sales: ${peso(sales)}\n`,
      attachments: [{ filename: `ledger-${scope}-${anchor}.pdf`, content: base64 }],
    }),
  });

  const body = await res.text();
  return new Response(body, { status: res.ok ? 200 : 502 });
});
