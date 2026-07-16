# Klikk Travel — Sales Dashboard

An interactive sales dashboard for Klikk Travel's travel business, built from the **KLIKK 2021 › DAILY TRANSACTIONS** Google Sheet.

## View it

Open [`sales_dashboard.html`](sales_dashboard.html) directly in a browser — it's a single self-contained file, no build step or server required.

## What's inside

- **Top KPIs** — total sales, revenue, orders, AOV, gross profit, profit margin, and cash flow, scoped to the *latest* period matching the granularity control (click Daily and see today's numbers, Weekly for this week, Monthly for the full calendar month, etc.)
- **Breakdown by period** — total SRP, cash flow, and transactions for every period at the selected granularity (most recent first); monthly periods are labeled with their real calendar range (e.g. "Jul 1–31")
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

5,185 real transactions from Jan 1, 2021 to Jul 15, 2026, each with complete financials (revenue, cost, commission, profit). Every KPI, chart, and table is computed live from that embedded dataset — nothing is padded, sampled, or estimated. Destination names are case-normalized (e.g. "Boracay" and "BORACAY" in the source sheet are merged) but otherwise left as entered; free-text variants of the same place (e.g. "CAGAYAN" vs "CAGAYAN DE ORO" vs "CDO") are not merged.

## Refreshing the data

This is a static snapshot (embedded as a compact JSON array inside the HTML `<script>` block), not a live connection to Google Sheets. To refresh, ask Claude to pull the latest rows from the sheet and regenerate the embedded data — it's not practical to hand-edit given the row count.

## Privacy note

The dashboard embeds real client names alongside transaction data (needed for the customer-insight sections). No raw sheet exports are kept in this repository — only the cleaned, embedded dataset inside `sales_dashboard.html`.
