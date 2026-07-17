# Klikk Travel — Sales Dashboard

An interactive sales dashboard for Klikk Travel's travel business, built from the **KLIKK 2021 › DAILY TRANSACTIONS** and **EXPENSES** Google Sheet tabs.

## View it

Open [`sales_dashboard.html`](sales_dashboard.html) directly in a browser — it's a single self-contained file, no build step or server required.

## What's inside

- **Top KPIs** — total sales, revenue, orders, AOV, gross profit, profit margin, cash flow, and total expenses, scoped to the *latest* period matching the granularity control (click Daily and see today's numbers, Weekly for this week, Monthly for the full calendar month, etc.). **Total Revenue here = Total Cash Flow − Total Expenses** (by request) — this is different from "revenue" elsewhere on the page (see note below). Cash flow specifically only counts **completed** transactions, recognized on their **processed date** — every other KPI uses the booking date and isn't status-filtered.
  > **Naming note:** the Top KPI "Total Revenue" card (cash flow minus expenses) is a different number from "revenue" in the Product/Regional/Sales Channel/Agent Performance sections and the Sales Performance charts, which is booked SRP per transaction — expenses aren't attributable to a specific product, region, rep, or channel, so those breakdowns couldn't use the same formula. If this dual meaning of "revenue" is confusing, say so and it can be relabeled (e.g. "Net Revenue" for the KPI card).
- **Expenses** — total spend by type (Salary, FB Ads, Rent, Miscellaneous, etc.) from the sheet's EXPENSES tab, with a donut and full ranked breakdown table. Only follows the date-range filter, not region/category/rep/channel (those dimensions don't exist for expense records).
- **Breakdown by period** — total SRP, cash flow, and transactions for every period at the selected granularity (most recent first); monthly periods are labeled with their real calendar range (e.g. "Jul 1–31"). SRP and transaction counts are by booking date; cash flow is completed-only, by processed date — so a period can show SRP with little or no cash flow if those bookings haven't been processed yet.
- **Sales performance** — trend (daily/weekly/monthly/quarterly/yearly), revenue vs. profit, target vs. actual
- **Product analysis** — top 10 best-selling products, a "needs attention" list of low-revenue products with 10+ orders, sales by product category, package status mix
- **Customer insights** — new vs. returning clients, acquisition trend, top 10 customers by revenue (aggregated across all their orders)
- **Regional performance** — an origin–destination route map (Manila → top destinations by revenue) plus a ranked revenue/profit table
- **Sales channel analysis** — revenue and performance by channel (Walk-in, Ads, No Ads, B2B, Referral)
- **Agent performance** — revenue by sales rep (top 15 chart, full ranked table), click a bar to filter
- **Filters** — trend granularity (drives both the Top KPIs period and the period breakdown table), custom date range, region, product category, sales rep, sales channel, with click-to-filter drill-down on charts and rows
- **Export** — CSV, Excel, and PDF (print)

## Data mapping

| Dashboard concept | Sheet field |
|---|---|
| Region | Destination |
| Product | Package (raw text, e.g. "ALL IN W/ CITY TOUR") |
| Product category | Package, grouped by keyword (All-Inclusive, Ticket, Land Arrangement, Tour, Visa Processing, Baggage, Insurance, Travel Tax, Rebooking, B2B, Transfer, Passport, Hotel, Other) |
| Sales rep | Agent |
| Sales channel | The sheet's ADS/lead-source field, normalized to Walk-in / Ads / No Ads / B2B / Referral / Unspecified |

The sheet doesn't track literal online/retail/wholesale/marketplace channels or a dedicated customer-segment field, so those aren't represented as separate dimensions.

## Scope

**VSP-channel transactions are excluded from this dashboard by standing request.** Of 5,284 valid transactions in the DAILY TRANSACTIONS tab, 99 tagged with the VSP channel were removed, leaving **5,185 transactions** that power every number on this page.

## Data coverage

5,185 real transactions from Jan 1, 2021 to Jul 15, 2026, each with complete financials (revenue, cost, commission, profit), plus 5,421 expense records from Dec 29, 2020 to Jul 13, 2026. Every KPI, chart, and table is computed live from that embedded dataset — nothing is padded, sampled, or estimated. Destination names and expense types are case-normalized (e.g. "Boracay"/"BORACAY" and "Load"/"LOAD" in the source sheets are merged) but otherwise left as entered; free-text variants of the same place (e.g. "CAGAYAN" vs "CAGAYAN DE ORO" vs "CDO") are not merged.

**A note on how the EXPENSES tab was pulled:** Google's export tool for this connector always returns whichever sheet tab is in the *first (leftmost)* position in the spreadsheet — it doesn't track which tab is "open" in a browser. To pull the EXPENSES tab, it had to be temporarily dragged to the first position, then DAILY TRANSACTIONS was moved back afterward. Future refreshes of either dataset require the same temporary reordering.

## Refreshing the data

This is a static snapshot (embedded as a compact JSON array inside the HTML `<script>` block), not a live connection to Google Sheets. To refresh, ask Claude to pull the latest rows from the sheet and regenerate the embedded data — it's not practical to hand-edit given the row count.

## Privacy note

The dashboard embeds real client names alongside transaction data (needed for the customer-insight sections). No raw sheet exports are kept in this repository — only the cleaned, embedded dataset inside `sales_dashboard.html`.
