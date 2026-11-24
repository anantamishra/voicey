import LockIcon from "../icons/shared/LockIcon";

type Kind = "live" | "hands" | "work" | "done";

/** The floating Voicey pop-up (level meter plus live words), as it looks in the app. Decorative only. */
export default function Pop({ kind, children, className = "" }: { kind: Kind; children: string; className?: string }) {
  return (
    <div className={`v-pop v-${kind} ${className}`.trim()}>
      {(kind === "live" || kind === "hands") && (
        <span className="v-meter">
          <i />
          <i />
          <i />
          <i />
          <i />
        </span>
      )}
      {kind === "hands" && <LockIcon className="v-lock" width="12" height="12" />}
      {kind === "work" && <span className="v-spin" />}
      {kind === "done" && <span className="v-check">✓</span>}
      <span className="v-pop-text">{children}</span>
    </div>
  );
}
