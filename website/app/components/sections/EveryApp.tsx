import Pop from "../mock/Pop";
import Win from "../mock/Win";

const TABS = ["any app", "email", "chat", "writing", "code", "ai chats"];

export default function EveryApp() {
  return (
    <section id="work" className="section wrap centered">
      <h2>
        built for <em>every</em> app.
      </h2>
      <p className="body">if you can type there, you can talk there.</p>
      <div className="ek">
        <div className="ek-chips" role="tablist" aria-label="where you use it">
          {TABS.map((t, i) => (
            <button key={t} type="button" role="tab" aria-selected={i === 0} className={i === 0 ? "ek-on" : undefined}>
              {t}
            </button>
          ))}
        </div>
        <div aria-hidden="true">
          <div className="ek-stage">
            <div className="ek-scene ek-on">
              <Win title="Untitled" className="v-wide">
                <div className="v-text v-big">
                  <p>Meeting notes. We agreed to ship the new onboarding on Thursday, and Priya will update the docs.</p>
                  <i className="v-caret" />
                </div>
              </Win>
              <Pop kind="done" className="v-at-bottom">
                Meeting notes. We agreed to ship the new onboarding on Thursday…
              </Pop>
            </div>
            <div className="ek-scene">
              <Win title="New Message" className="v-wide v-mail">
                <div className="v-fields">
                  <p>
                    <span>To:</span> Anjali
                  </p>
                  <p>
                    <span>Subject:</span> Invoice for March
                  </p>
                </div>
                <div className="v-text v-big">
                  <p>Hi Anjali, thanks for your patience. I&rsquo;ve attached the March invoice. Let me know if anything looks off.</p>
                  <i className="v-caret" />
                </div>
              </Win>
              <Pop kind="done" className="v-at-bottom">
                Hi Anjali, thanks for your patience. I&rsquo;ve attached the March invoice…
              </Pop>
            </div>
            <div className="ek-scene">
              <Win title="# general" className="v-wide v-chat">
                <div className="v-bubbles">
                  <p className="them">can you review the PR before standup?</p>
                  <p className="me">on it, give me ten minutes</p>
                </div>
                <div className="v-compose">
                  <span>sounds good, I&rsquo;ll leave comments inline</span>
                  <i className="v-caret" />
                </div>
              </Win>
              <Pop kind="live" className="v-at-bottom">
                sounds good I&rsquo;ll leave comments inline
              </Pop>
            </div>
            <div className="ek-scene">
              <Win title="Draft" className="v-wide v-doc">
                <div className="v-text v-big">
                  <h4>A short note on focus</h4>
                  <p>The best writing days start with a single sentence. Say it out loud first, then keep going.</p>
                  <i className="v-caret" />
                </div>
              </Win>
              <Pop kind="done" className="v-at-bottom">
                The best writing days start with a single sentence.
              </Pop>
            </div>
            <div className="ek-scene">
              <Win title="parser.ts" className="v-wide v-code">
                <pre>
                  <span className="c">{"// "}</span>
                  <span className="c typed">return an error instead of throwing when the input is empty</span>
                  <i className="v-caret light" />
                </pre>
              </Win>
              <Pop kind="done" className="v-at-bottom">
                return an error instead of throwing when the input is empty
              </Pop>
            </div>
            <div className="ek-scene">
              <Win title="Ask anything" className="v-wide v-ai">
                <div className="v-bubbles">
                  <p className="them">What can I help you with?</p>
                </div>
                <div className="v-compose big">
                  <span>Summarise this contract in five bullet points and flag anything unusual.</span>
                  <i className="v-caret" />
                </div>
              </Win>
              <Pop kind="done" className="v-at-bottom">
                Summarise this contract in five bullet points…
              </Pop>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
