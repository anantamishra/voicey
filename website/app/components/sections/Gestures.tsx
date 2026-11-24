import Pop from "../mock/Pop";

export default function Gestures() {
  return (
    <section id="features" className="section wrap centered">
      <h2>
        made for <em>fast</em> writing.
      </h2>
      <div className="moments">
        <figure className="moment">
          <div className="m-photo vp vp-1" aria-hidden="true">
            <div className="vm">
              <div className="v-keys static">
                <kbd>⌃</kbd>
                <kbd>⌥</kbd>
                <kbd className="wide down">space</kbd>
              </div>
              <Pop kind="live">hey can you send me the report by friday</Pop>
            </div>
          </div>
          <figcaption>
            <b>hold to talk</b>
            <span>press and hold your shortcut, say it, let go. that&rsquo;s it.</span>
          </figcaption>
        </figure>
        <figure className="moment">
          <div className="m-photo vp vp-2" aria-hidden="true">
            <div className="vm">
              <div className="v-keys static">
                <kbd className="wide">space</kbd>
                <span className="tap">×2</span>
              </div>
              <Pop kind="hands">Listening hands-free… press to stop</Pop>
            </div>
          </div>
          <figcaption>
            <b>double-tap for hands-free</b>
            <span>keep talking without holding a key. press once more when you&rsquo;re done.</span>
          </figcaption>
        </figure>
        <figure className="moment">
          <div className="m-photo vp vp-5" aria-hidden="true">
            <div className="vm">
              <div className="clap">
                <span>👏</span>
                <span>👏</span>
              </div>
              <Pop kind="hands">Listening hands-free… pause to finish</Pop>
            </div>
          </div>
          <figcaption>
            <b>start with a double clap</b>
            <span>no keyboard needed: clap twice and talk. it&rsquo;s off until you turn it on in settings.</span>
          </figcaption>
        </figure>
        <figure className="moment">
          <div className="m-photo vp vp-6" aria-hidden="true">
            <div className="vm">
              <Pop kind="live">send it to marcus by friday</Pop>
              <span className="pause-note">3 quiet seconds</span>
              <Pop kind="work">Transcribing…</Pop>
            </div>
          </div>
          <figcaption>
            <b>stops when you pause</b>
            <span>finish talking and voicey transcribes by itself after a few quiet seconds. choose 2, 3 or 5, or never.</span>
          </figcaption>
        </figure>
        <figure className="moment">
          <div className="m-photo vp vp-3" aria-hidden="true">
            <div className="vm vm-tone">
              <div className="tone-card">
                <span className="tone-app">Mail · formal</span>
                <p>Dear Ms. Patel, please find the report attached.</p>
              </div>
              <div className="tone-card">
                <span className="tone-app">Messages · casual</span>
                <p>hey, sending the report now!</p>
              </div>
            </div>
          </div>
          <figcaption>
            <b>writes the way each app needs</b>
            <span>formal in mail, casual in messages. you choose the tone for every app.</span>
          </figcaption>
        </figure>
        <figure className="moment">
          <div className="m-photo vp vp-4" aria-hidden="true">
            <div className="vm vm-dict">
              <div className="chips">
                <span>Priya</span>
                <span>Kubernetes</span>
                <span>Zürich</span>
                <span>Acme Corp</span>
              </div>
              <p className="snip">
                <span>my address</span>
                <i>→</i> 42 Wallaby Way, Sydney
              </p>
            </div>
          </div>
          <figcaption>
            <b>your words, spelled right</b>
            <span>add the names you say often. say a short phrase and it expands to the full text.</span>
          </figcaption>
        </figure>
      </div>
    </section>
  );
}
