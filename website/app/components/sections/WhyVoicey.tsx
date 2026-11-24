import CheckIcon from "../icons/WhyVoicey/CheckIcon";
import Logo from "../icons/shared/Logo";

type Cell = "yes" | "no" | string;

const ROWS: { label: string; cells: [Cell, Cell, Cell] }[] = [
  { label: "your voice stays on your mac", cells: ["yes", "partly", "no"] },
  { label: "removes “um”s and fixes punctuation", cells: ["yes", "punctuation", "usually"] },
  { label: "a different tone for each app", cells: ["yes", "no", "varies"] },
  { label: "your own dictionary and snippets", cells: ["yes", "partly", "varies"] },
  { label: "free and open source", cells: ["yes", "no", "varies"] },
];

function CellView({ value, us }: { value: Cell; us?: boolean }) {
  return (
    <span role="cell" className={us ? "cmp-us" : undefined}>
      {value === "yes" ? (
        <span className="cmp-yes" aria-label="yes">
          <CheckIcon width="24" height="24" aria-hidden="true" />
        </span>
      ) : value === "no" ? (
        <span className="cmp-no" aria-label="no" />
      ) : (
        <span className="cmp-text">{value}</span>
      )}
    </span>
  );
}

export default function WhyVoicey() {
  return (
    <section className="section wrap centered">
      <h2>
        why <em>voicey</em>?
      </h2>
      <p className="body">it listens on your mac, writes like you, and works in every app.</p>
      <div className="cmp v3" role="table" aria-label="voicey compared with built-in dictation and cloud dictation apps">
        <div className="cmp-row cmp-head" role="row">
          <span role="columnheader" />
          <span role="columnheader" className="cmp-us">
            <span className="cmp-brand">
              <Logo width="22" height="20" />
              voicey
            </span>
          </span>
          <span role="columnheader">
            <span className="cmp-brand">built-in dictation</span>
          </span>
          <span role="columnheader">
            <span className="cmp-brand">cloud dictation apps</span>
          </span>
        </div>
        {ROWS.map((r) => (
          <div className="cmp-row" role="row" key={r.label}>
            <span role="rowheader" className="cmp-label">
              {r.label}
            </span>
            <CellView value={r.cells[0]} us />
            <CellView value={r.cells[1]} />
            <CellView value={r.cells[2]} />
          </div>
        ))}
      </div>
    </section>
  );
}
