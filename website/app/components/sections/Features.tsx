const CARDS = [
  { icon: "🎙️", text: "Hold your shortcut, talk, let go. The text lands where your cursor is.", tag: "hold to talk" },
  { icon: "🤲", text: "Double-tap to keep talking hands-free, as long as you like.", tag: "hands-free" },
  { icon: "⌨️", text: "Use any key you want, even a single one like fn or Right ⌥.", tag: "your shortcut" },
  { icon: "🔒", text: "Your voice is turned into text on your Mac. The audio is never uploaded.", tag: "private" },
  { icon: "✨", text: "Claude Code or Codex tidies the text: punctuation, filler words, the lot.", tag: "ai polish" },
  { icon: "📖", text: "Teach it the names and terms you say often, and it spells them right.", tag: "dictionary" },
  { icon: "🎨", text: "Formal in Mail, casual in Messages. Pick a tone for every app.", tag: "per-app tone" },
  { icon: "✂️", text: "Say “my address” and the whole thing appears, word for word.", tag: "snippets" },
  { icon: "👀", text: "A live pop-up shows your words as you speak them.", tag: "live preview" },
  { icon: "🌍", text: "Many languages, with the multilingual speech models.", tag: "languages" },
  { icon: "📋", text: "Lost the last thing you said? Copy it again from the menu bar.", tag: "copy last" },
  { icon: "🔄", text: "Free, open source and it updates itself.", tag: "mit license" },
];

function Row({ cards, reverse }: { cards: typeof CARDS; reverse?: boolean }) {
  const copy = (
    <div className="says-copy">
      {cards.map((c) => (
        <div className="say" key={c.tag}>
          <p className="say-quote">{c.text}</p>
          <div className="say-who">
            <span className="say-face" aria-hidden="true">
              {c.icon}
            </span>
            <span className="say-name">
              <b>{c.tag}</b>
            </span>
          </div>
        </div>
      ))}
    </div>
  );
  return (
    <div className={reverse ? "says-row reverse" : "says-row"}>
      <div className="says-track u-ba5818">
        {copy}
        {copy}
      </div>
    </div>
  );
}

/** A scrolling wall of the small things Voicey does. (No testimonials: those need real people.) */
export default function Features() {
  return (
    <section id="love" className="section wrap centered">
      <h2>
        the <em>little</em> things.
      </h2>
      <p className="body">small details that make talking to your mac feel natural.</p>
      <div className="says">
        <ul className="sr-only">
          {CARDS.map((c) => (
            <li key={c.tag}>
              {c.tag}: {c.text}
            </li>
          ))}
        </ul>
        <div aria-hidden="true">
          <Row cards={CARDS.slice(0, 6)} />
          <Row cards={CARDS.slice(6)} reverse />
        </div>
      </div>
    </section>
  );
}
