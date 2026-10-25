// Small SVG/HTML charts: monthly stacked columns with hover tooltip, and a status stack.

import { useState } from "react";
import { fmtMoney } from "../lib/format";
import { seriesColor } from "./kit";

const MONTHS = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"];

export interface Series { name: string; values: number[]; colorIndex: number }

/** Stacked monthly columns (one series per plant). Colors follow the entity's fixed index. */
export function MonthlyColumns({ series, highlightMonth, height = 220 }: { series: Series[]; highlightMonth?: number; height?: number }) {
  const [hover, setHover] = useState<number | null>(null);
  const totals = MONTHS.map((_, m) => series.reduce((s, x) => s + (x.values[m] ?? 0), 0));
  const max = Math.max(1, ...totals);
  const top = niceCeil(max);
  const ticks = [0, 0.25, 0.5, 0.75, 1].map((t) => t * top);
  const W = 720, H = height, padL = 54, padB = 24, padT = 8;
  const plotW = W - padL - 8, plotH = H - padB - padT;
  const colW = plotW / 12;
  const barW = Math.min(30, colW * 0.6);

  return (
    <div style={{ position: "relative" }}>
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label="Ingresos programados por mes y planta" style={{ display: "block", overflow: "visible" }}>
        {ticks.map((t) => {
          const y = padT + plotH - (t / top) * plotH;
          return (
            <g key={t}>
              <line x1={padL} x2={W - 8} y1={y} y2={y} stroke="var(--stroke)" />
              <text x={padL - 8} y={y + 4} textAnchor="end" fontSize="11" fill="var(--text-3)">{fmtMoney(t, true)}</text>
            </g>
          );
        })}
        {MONTHS.map((label, m) => {
          const x = padL + m * colW + (colW - barW) / 2;
          let acc = 0;
          return (
            <g key={label} onMouseEnter={() => setHover(m)} onMouseLeave={() => setHover(null)}>
              <rect x={padL + m * colW} y={padT} width={colW} height={plotH} fill={hover === m ? "var(--fill)" : "transparent"} />
              {series.map((s) => {
                const v = s.values[m] ?? 0;
                if (v <= 0) return null;
                const h = (v / top) * plotH;
                const y = padT + plotH - ((acc + v) / top) * plotH;
                acc += v;
                return <rect key={s.name} x={x} y={y + 1} width={barW} height={Math.max(0, h - 2)} rx={4} fill={seriesColor(s.colorIndex)} />;
              })}
              <text x={padL + m * colW + colW / 2} y={H - 6} textAnchor="middle" fontSize="11" fontWeight={highlightMonth === m ? 800 : 500} fill={highlightMonth === m ? "var(--text)" : "var(--text-3)"}>{label}</text>
            </g>
          );
        })}
      </svg>
      {hover != null && totals[hover] > 0 && (
        <div className="chart-tip" style={{ left: `${((padL + hover * colW + colW / 2) / W) * 100}%`, top: 0, transform: "translateX(-50%)" }}>
          <div className="bold" style={{ marginBottom: 4 }}>{MONTHS[hover]} · {fmtMoney(totals[hover])}</div>
          {series.filter((s) => (s.values[hover] ?? 0) > 0).map((s) => (
            <div key={s.name} className="row" style={{ gap: 6 }}>
              <i style={{ width: 9, height: 9, borderRadius: 3, background: seriesColor(s.colorIndex), display: "inline-block" }} />
              <span className="grow">{s.name}</span>
              <span className="num bold">{fmtMoney(s.values[hover] ?? 0, true)}</span>
            </div>
          ))}
        </div>
      )}
      {series.length > 1 && (
        <div className="legend" style={{ marginTop: 10 }}>
          {series.map((s) => (
            <span key={s.name}><i style={{ background: seriesColor(s.colorIndex) }} />{s.name}</span>
          ))}
        </div>
      )}
    </div>
  );
}

function niceCeil(v: number) {
  const exp = Math.pow(10, Math.floor(Math.log10(v)));
  const f = v / exp;
  const nice = f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10;
  return nice * exp;
}

/** Horizontal stacked share bar with a labeled legend (status counts). */
export function StatusStack({ items }: { items: { label: string; value: number; color: string }[] }) {
  const total = items.reduce((s, i) => s + i.value, 0);
  return (
    <div className="col" style={{ gap: 12 }}>
      <div className="stack" role="img" aria-label={items.map((i) => `${i.label}: ${i.value}`).join(", ")}>
        {total > 0 && items.filter((i) => i.value > 0).map((i) => <span key={i.label} title={`${i.label}: ${i.value}`} style={{ width: `${(i.value / total) * 100}%`, background: i.color }} />)}
      </div>
      <div className="col" style={{ gap: 8 }}>
        {items.map((i) => (
          <div key={i.label} className="row small">
            <i style={{ width: 10, height: 10, borderRadius: 3, background: i.color, display: "inline-block" }} />
            <span className="grow muted">{i.label}</span>
            <span className="bold num">{i.value}</span>
            <span className="faint num" style={{ width: 44, textAlign: "right" }}>{total ? Math.round((i.value / total) * 100) : 0}%</span>
          </div>
        ))}
      </div>
    </div>
  );
}
