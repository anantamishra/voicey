import Logo from "../icons/shared/Logo";

export default function MakerNote() {
  return (
    <section id="story" className="section wrap centered">
      <h2>
        why I <em>built</em> voicey.
      </h2>
      <article className="fn-window">
        <header className="fn-bar">
          <span className="fn-dots" aria-hidden="true">
            <i />
            <i />
            <i />
          </span>
          <span className="fn-title">
            <span className="fn-icon" aria-hidden="true" />
            notes
          </span>
        </header>
        <div className="fn-body">
          <p>
            voicey is a small open-source project by{" "}
            <a className="v-link" href="https://github.com/anantamishra/" target="_blank" rel="noopener noreferrer">
              ananta mishra
            </a>
            .
          </p>
          <p>i wanted dictation that stays on my mac, writes the way i write, and works in every app, instead of one more thing in the cloud.</p>
          <p>
            so it runs whisper on your mac, then asks the ai tool you already use to tidy the words: <mark>voicey. talk, and it types.</mark>
          </p>
          <p>it&rsquo;s early, and it&rsquo;s free. try it, and tell me what you think.</p>
        </div>
        <footer className="fn-sign">
          <span className="fn-who">
            <span className="fn-face v-face" aria-hidden="true">
              <Logo width="26" height="24" />
            </span>
            <span>
              <a className="v-link" href="https://github.com/anantamishra/" target="_blank" rel="noopener noreferrer">
                ananta
              </a>
              ,<br />
              <small>maker</small>
            </span>
          </span>
          <span className="fn-hand caveat_954b711f-module__ahyxHq__className">voicey</span>
        </footer>
      </article>
    </section>
  );
}
