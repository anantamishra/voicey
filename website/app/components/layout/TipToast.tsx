import CloseIcon from "../icons/shared/CloseIcon";

/** A small rotating tip in the corner. The text cycles in Interactions.tsx. */
export default function TipToast() {
  return (
    <aside className="proof on" aria-label="a tip for using voicey" aria-hidden="false">
      <button type="button" className="proof-close" aria-label="close" tabIndex={0}>
        <CloseIcon width="12" height="12" aria-hidden="true" />
      </button>
      <p className="proof-quote">tip: double-tap your shortcut to talk hands-free. press once more to stop.</p>
      <div className="proof-who">
        <span className="say-face tip-face" aria-hidden="true">
          💡
        </span>
        <span className="say-name">
          <b>voicey tip</b>
          <span>1 of 6</span>
        </span>
      </div>
    </aside>
  );
}
