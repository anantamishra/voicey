import { asset } from "../../lib/links";
import Pop from "../mock/Pop";
import Win from "../mock/Win";

const ORBS = [
  { cls: "u-ba51e2", src: "/tiles/doc.svg" },
  { cls: "u-c148a2", src: "/tiles/mail.svg" },
  { cls: "u-fe639d", src: "/tiles/chat.svg" },
  { cls: "u-ef9cd4", src: "/tiles/code.svg" },
  { cls: "u-891731", src: "/tiles/notes.svg" },
];

/**
 * The scroll-driven demo. `data-step` (0 to 3) is set by Interactions.tsx as you scroll:
 * 0 press, 1 talk, 2 polish, 3 pasted.
 */
export default function DictationStory() {
  return (
    <section className="story" data-step="0" aria-label="How Voicey works when you dictate an email">
      <div className="story-sticky wrap">
        <div className="stage">
          <div className="orbit" aria-hidden="true">
            <span className="orbit-ring" />
            <span className="orbit-ring front" />
            {ORBS.map((o) => (
              <span key={o.src} className={`orb ${o.cls}`}>
                <img src={asset(o.src)} alt="" />
              </span>
            ))}
          </div>
          <div className="frame">
            <div
              className="v-scene"
              role="img"
              aria-label="A new email. The person holds a shortcut and says: hey can you send me the report by friday thanks. Voicey writes: Hey, can you send me the report by Friday? Thanks."
            >
              <Win title="New Message" className="v-mail">
                <div className="v-fields">
                  <p>
                    <span>To:</span> Marcus
                  </p>
                  <p>
                    <span>Subject:</span> Friday report
                  </p>
                </div>
                <div className="v-text">
                  <p className="v-typed">Hey, can you send me the report by Friday? Thanks.</p>
                  <i className="v-caret" />
                </div>
              </Win>
              <div className="v-keys" aria-hidden="true">
                <kbd>⌃</kbd>
                <kbd>⌥</kbd>
                <kbd className="wide">space</kbd>
                <span>hold to talk</span>
              </div>
              <Pop kind="live" className="v-s1">
                um so hey can you uh send me the report by friday thanks
              </Pop>
              <Pop kind="work" className="v-s2">
                Polishing with Claude…
              </Pop>
              <Pop kind="done" className="v-s3">
                Hey, can you send me the report by Friday? Thanks.
              </Pop>
            </div>
          </div>
          <ol className="v-steps" aria-hidden="true">
            <li>
              <b>1</b> press your shortcut
            </li>
            <li>
              <b>2</b> talk
            </li>
            <li>
              <b>3</b> it polishes
            </li>
            <li>
              <b>4</b> it&rsquo;s pasted
            </li>
          </ol>
        </div>
      </div>
    </section>
  );
}
