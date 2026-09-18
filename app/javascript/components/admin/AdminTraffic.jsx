import React, { useEffect, useState } from "react";
import { useSearchParams } from "react-router";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faXmark, faDownload } from "@fortawesome/free-solid-svg-icons";
import { adminGet } from "./adminApi";
import { authFetch, formatDate } from "../helpers/utils";

const WINDOWS = [
  ["1h", "Last hour"],
  ["12h", "Last 12 hours"],
  ["24h", "Last 24 hours"],
  ["7d", "Last 7 days"],
  ["30d", "Last 30 days"],
  ["90d", "Last 90 days"],
  ["365d", "Last 365 days"],
];

const CLIENTS = [
  ["", "All"],
  ["web", "Web"],
  ["api", "API"],
];

const formatCount = (n) => n.toLocaleString();

const compactCount = (n) =>
  new Intl.NumberFormat("en-US", { notation: "compact", maximumFractionDigits: 1 }).format(n).toLowerCase();

const share = (count, total) => (total > 0 ? `${((count / total) * 100).toFixed(1)}%` : "");

const pct = (count, total) => (total > 0 ? `${Math.round((count / total) * 100)}%` : "0%");

const formatAt = (iso, bucket) => {
  if (bucket === "day") return formatDate(iso.slice(0, 10));
  return new Date(iso).toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric" });
};

export const trafficStats = (data, { clients = true } = {}) => {
  const loggedIn = data.logged_in.true || 0;
  const anonymous = data.logged_in.false || 0;
  return [
    ...(clients ? [["Web", formatCount(data.clients.web || 0)], ["API", formatCount(data.clients.api || 0)]] : []),
    ["Logged in", `${formatCount(loggedIn)} (${pct(loggedIn, data.total)})`],
    ["Anonymous", `${formatCount(anonymous)} (${pct(anonymous, data.total)})`],
  ];
};

const PAGE_SIZE = 25;

const BreakdownTable = ({ title, rows, total, distinct, onPick }) => {
  const [shown, setShown] = useState(PAGE_SIZE);
  useEffect(() => setShown(PAGE_SIZE), [rows]);
  const visible = rows.slice(0, shown);
  const truncated = distinct > rows.length;
  return (
  <section className="admin-card">
    <header className="admin-card-header">
      <h2>
        {title}
        {distinct > 0 && <span className="admin-count">{formatCount(distinct)}</span>}
      </h2>
    </header>
    <div className="admin-card-body">
      {rows.length === 0 ? (
        <p className="admin-empty">Nothing recorded.</p>
      ) : (
        <table className="admin-traffic-table">
          <tbody>
            {visible.map((row) => (
              <tr key={row.value}>
                <td className="admin-traffic-value" title={onPick ? undefined : row.value}>
                  {onPick ? (
                    <button type="button" className="admin-traffic-link" title="Show only this IP" onClick={() => onPick(row.value)}>
                      {row.value}
                    </button>
                  ) : (
                    row.value || "(blank)"
                  )}
                </td>
                <td className="admin-traffic-count">{formatCount(row.count)}</td>
                <td className="admin-traffic-share">{share(row.count, total)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      {rows.length > 0 && (
        <footer className="admin-traffic-table-footer">
          <span>
            {formatCount(visible.length)} of {formatCount(distinct)}
            {truncated && shown >= rows.length ? ` (top ${formatCount(rows.length)} loaded)` : ""}
          </span>
          {shown < rows.length && (
            <button type="button" onClick={() => setShown((n) => n + PAGE_SIZE)}>Show more</button>
          )}
        </footer>
      )}
    </div>
  </section>
  );
};

const SeriesBars = ({ series, bucket, stacked }) => {
  const max = Math.max(1, ...series.map((d) => d.count));
  const first = series[0];
  const last = series[series.length - 1];
  const tip = (d) =>
    stacked
      ? `${formatAt(d.at, bucket)}: ${formatCount(d.count)} (web ${formatCount(d.web)}, API ${formatCount(d.api)})`
      : `${formatAt(d.at, bucket)}: ${formatCount(d.count)}`;
  return (
    <div className="admin-traffic-chart">
      <div className="admin-traffic-bars" role="img" aria-label={`Requests per ${bucket}`}>
        {series.map((d) => (
          <span
            key={d.at}
            className={`admin-traffic-bar${stacked ? " is-stacked" : ""}`}
            style={{ height: `${Math.max(2, (d.count / max) * 100)}%` }}
            title={tip(d)}
          >
            {stacked && d.count > 0 && (
              <>
                <i className="is-api" style={{ flexBasis: `${(d.api / d.count) * 100}%` }} />
                <i className="is-web" style={{ flexBasis: `${(d.web / d.count) * 100}%` }} />
              </>
            )}
          </span>
        ))}
      </div>
      <div className="admin-traffic-axis">
        <span>{formatAt(first.at, bucket)}</span>
        <span>Peak {compactCount(max)}/{bucket}</span>
        <span>{formatAt(last.at, bucket)}</span>
      </div>
    </div>
  );
};

const RADIUS = 40;
const STROKE = 14;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;
const GAP = 2;

const ClientDonut = ({ data }) => {
  const web = data.clients.web || 0;
  const api = data.clients.api || 0;
  const total = web + api;
  const slices = [
    { key: "web", label: "Web", count: web, className: "is-web" },
    { key: "api", label: "API", count: api, className: "is-api" },
  ].filter((s) => s.count > 0);
  let offset = 0;
  return (
    <figure className="admin-traffic-donut">
      <svg viewBox="0 0 100 100" role="img" aria-label={`Web ${pct(web, total)}, API ${pct(api, total)}`}>
        {slices.map((s) => {
          const length = (s.count / total) * CIRCUMFERENCE;
          const gap = slices.length > 1 ? GAP : 0;
          const dash = `${Math.max(0, length - gap)} ${CIRCUMFERENCE - Math.max(0, length - gap)}`;
          const rotate = -90 + (offset / CIRCUMFERENCE) * 360;
          offset += length;
          return (
            <circle
              key={s.key}
              className={`admin-traffic-slice ${s.className}`}
              cx="50"
              cy="50"
              r={RADIUS}
              fill="none"
              strokeWidth={STROKE}
              strokeDasharray={dash}
              transform={`rotate(${rotate} 50 50)`}
            >
              <title>{`${s.label}: ${formatCount(s.count)} (${pct(s.count, total)})`}</title>
            </circle>
          );
        })}
        <text x="50" y="47" textAnchor="middle" className="admin-traffic-donut-value">{pct(web, total)}</text>
        <text x="50" y="60" textAnchor="middle" className="admin-traffic-donut-label">web</text>
      </svg>
    </figure>
  );
};

const ClientTile = ({ data }) => {
  const web = data.clients.web || 0;
  const api = data.clients.api || 0;
  const total = web + api;
  return (
    <div className="admin-traffic-client-tile">
      <ClientDonut data={data} />
      <dl>
        {[["Web", web, "is-web"], ["API", api, "is-api"]].map(([label, count, cls]) => (
          <div key={label}>
            <dt><i className={`admin-traffic-swatch ${cls}`} />{label}</dt>
            <dd>{formatCount(count)} ({pct(count, total)})</dd>
          </div>
        ))}
      </dl>
    </div>
  );
};

const Overview = ({ data }) => (
  <div className="admin-traffic-stats">
    <ClientTile data={data} />
    {trafficStats(data, { clients: false }).map(([label, value]) => (
      <dl key={label}>
        <div>
          <dt>{label}</dt>
          <dd>{value}</dd>
        </div>
      </dl>
    ))}
  </div>
);

const AdminTraffic = () => {
  const [params, setParams] = useSearchParams();
  const windowKey = WINDOWS.some(([value]) => value === params.get("window")) ? params.get("window") : "30d";
  const client = CLIENTS.some(([value]) => value === params.get("client")) ? params.get("client") : "";
  const ip = params.get("ip") || "";
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [exporting, setExporting] = useState(false);

  const query = new URLSearchParams({ window: windowKey });
  if (client) query.set("client", client);
  if (ip) query.set("ip", ip);
  const queryString = query.toString();

  const exportData = async () => {
    setExporting(true);
    try {
      const response = await authFetch(`/api/v2/admin/traffic/export?${queryString}`);
      if (!response.ok) throw new Error(`Export failed (${response.status})`);
      const disposition = response.headers.get("Content-Disposition") || "";
      const filename = disposition.match(/filename="([^"]+)"/)?.[1] || "phishin-traffic.json";
      const url = URL.createObjectURL(await response.blob());
      const link = document.createElement("a");
      link.href = url;
      link.download = filename;
      link.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      setError(e.message);
    } finally {
      setExporting(false);
    }
  };

  useEffect(() => {
    let cancelled = false;
    setData(null);
    adminGet(`/traffic?${queryString}`)
      .then((result) => {
        if (!cancelled) setData(result);
      })
      .catch((e) => {
        if (!cancelled) setError(e.message);
      });
    return () => {
      cancelled = true;
    };
  }, [queryString]);

  const update = (changes) => {
    setParams((prev) => {
      const next = new URLSearchParams(prev);
      Object.entries(changes).forEach(([key, value]) => {
        if (value) next.set(key, value);
        else next.delete(key);
      });
      return next;
    });
  };

  return (
    <div className="admin-import admin-traffic-page">
      {error && <p className="admin-error">{error}</p>}

      <section className="admin-card">
        <header className="admin-card-header">
          <h2>
            {{ "": "Traffic", web: "Web Traffic", api: "API Traffic" }[client]}
            {data && <span className="admin-count">{formatCount(data.total)}</span>}
          </h2>
          <div className="admin-shows-filters">
            {ip && (
              <button type="button" className="admin-traffic-filter" onClick={() => update({ ip: "" })}>
                {ip} <FontAwesomeIcon icon={faXmark} />
              </button>
            )}
            <div className="admin-traffic-tabs">
              {CLIENTS.map(([value, label]) => (
                <button
                  key={value}
                  type="button"
                  className={client === value ? "is-active" : ""}
                  onClick={() => update({ client: value, ip: "" })}
                >
                  {label}
                </button>
              ))}
            </div>
            <select value={windowKey} onChange={(e) => update({ window: e.target.value })}>
              {WINDOWS.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
            </select>
            <button
              type="button"
              title="Download every route, IP and user agent for this window as JSON"
              disabled={exporting || !data || data.total === 0}
              onClick={exportData}
            >
              <FontAwesomeIcon icon={faDownload} /> {exporting ? "Exporting" : "Export"}
            </button>
          </div>
        </header>
        <div className="admin-card-body">
          {data === null ? (
            <p className="admin-empty">Loading</p>
          ) : data.total === 0 ? (
            <p className="admin-empty">No requests in this window.</p>
          ) : (
            <>
              {client === "" && <Overview data={data} />}
              <SeriesBars series={data.series} bucket={data.bucket} stacked={client === ""} />
            </>
          )}
        </div>
      </section>

      {data && data.total > 0 && (
        <div className="admin-traffic-grid">
          <BreakdownTable title="Routes" rows={data.routes} distinct={data.distinct.routes} total={data.total} />
          {client !== "web" && (
            <BreakdownTable
              title="IPs"
              rows={data.ips}
              distinct={data.distinct.ips}
              total={data.total}
              onPick={ip ? null : (value) => update({ ip: value })}
            />
          )}
          {client !== "web" && (
            <BreakdownTable title="User Agents" rows={data.user_agents} distinct={data.distinct.user_agents} total={data.total} />
          )}
        </div>
      )}
    </div>
  );
};

export default AdminTraffic;
