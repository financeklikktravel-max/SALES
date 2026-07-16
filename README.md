# Klikk Travel — Sales Dashboard

An interactive sales dashboard for Klikk Travel's visa-processing business, built from the **KLIKK 2021 › VISA TRANSACTIONS** Google Sheet.

## View it

Open [`sales_dashboard.html`](sales_dashboard.html) directly in a browser — it's a single self-contained file, no build step or server required.

## What's inside

- **Top KPIs** — total sales, revenue, orders, average order value, gross profit, profit margin
- **Sales performance** — monthly trend, revenue vs. profit, target vs. actual
- **Product analysis** — best/lowest performing destinations, sales mix by account type, package status mix
- **Customer insights** — new vs. returning clients, acquisition trend, top customers by revenue
- **Regional performance** — an origin–destination route map (Manila → each visa destination) plus a revenue comparison table
- **Sales channel analysis** — revenue and performance by account type (VSP / B2B)
- **Filters** — trend granularity (daily/weekly/monthly/quarterly/yearly), custom date range, region, product, sales rep, account type, with click-to-filter drill-down on charts
- **Export** — CSV, Excel, and PDF (print)

## Data mapping

The source sheet tracks visa-processing transactions, not a generic e-commerce catalog, so a few fields are repurposed:

| Dashboard concept | Sheet field |
|---|---|
| Region | Destination |
| Product category | Package (currently one type: Visa Processing) |
| Sales rep | Agent |
| Customer segment / Sales channel | Account (VSP = direct/retail, B2B = partner/wholesale) |

## Data coverage

Of 836 rows in the source sheet, 34 have a usable date + client name, and 3 have complete transaction financials. **VSP-channel transactions are excluded from this dashboard by request** — only B2B-channel activity is shown, leaving 1 closed transaction and 31 client/inquiry log entries in scope. KPIs, revenue/profit charts, and the target bullet are computed from that 1 transaction; the acquisition trend and new-vs-returning split draw on the 31-row log. Every number on the dashboard is computed live from the embedded data — nothing is padded or estimated.

## Refreshing the data

This is a static snapshot (embedded as JSON inside the HTML `<script>` block), not a live connection to Google Sheets. To refresh: pull the latest rows from the sheet and update the `TRANSACTIONS` and `LEADS` arrays near the top of the script in `sales_dashboard.html`.

## Privacy note

Raw exports of the source sheet (`klikk_raw.csv`, `klikk_decoded.csv`), which contain full client names and financial detail, are intentionally excluded from this repo via `.gitignore`. The dashboard itself only embeds the small subset of records needed to power the visuals.
