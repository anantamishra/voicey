import { DOWNLOAD_URL, asset } from "../../lib/links";
import AppleLogoIcon02 from "../icons/shared/AppleLogoIcon02";
import Logo from "../icons/shared/Logo";

export default function Typing() {
  return (
    <section id="why" className="section wrap centered pains-wrap">
      <h2>
        sound <em>familiar</em>?
      </h2>
      <p className="body">if you write a lot, you&rsquo;ve been here.</p>
      <div
        className="macbook"
        role="img"
        aria-label="A MacBook showing: 12 unread messages; writing a 1,400 word update by hand, about 35 minutes; and a dictation that kept every um and misspelled a name."
      >
        <div className="mb-lid">
          <span className="mb-notch" aria-hidden="true" />
          <div className="mb-screen">
            <div className="mb-menubar">
              <AppleLogoIcon02 width="11" height="13" aria-hidden="true" />
              <b>Notes</b>
              <span>File</span>
              <span>Edit</span>
              <span>View</span>
              <span className="mb-clock">Thu 6:42 PM</span>
            </div>
            <div className="scr-notif">
              <span className="scr-notif-app" aria-hidden="true">
                <img src={asset("/tiles/chat.svg")} alt="" />
              </span>
              <span>
                <b>12 unread messages</b>
                <span>Everyone is waiting for your reply.</span>
              </span>
              <small>now</small>
            </div>
            <div className="scr-prog">
              <p>
                <img src={asset("/tiles/notes.svg")} alt="" loading="lazy" decoding="async" />
                <b>Writing “Q4 update” by hand</b>
              </p>
              <span className="scr-prog-bar">
                <i />
              </span>
              <small>412 of 1,400 words · About 35 minutes</small>
            </div>
            <div className="scr-alert">
              <span className="scr-alert-icon" aria-hidden="true">
                <img src={asset("/brand/voicey-icon.png")} alt="" />
              </span>
              <b>Fix 7 mistakes?</b>
              <span>“um”, “uh” and a misspelled name. Plain dictation wrote it all down.</span>
              <span className="scr-alert-btns">
                <i>Ignore</i>
                <i className="del">Retype</i>
              </span>
            </div>
          </div>
        </div>
        <div className="mb-base" aria-hidden="true" />
      </div>
      <div className="pain-causes">
        <p className="pain-causes-head">why it happens</p>
        <p className="pain-cause">
          <span className="pain-logos">⌨️</span>most people speak about three times faster than they type.
        </p>
        <p className="pain-cause">
          <span className="pain-logos">🎙️</span>plain dictation writes every &ldquo;um&rdquo; and mangles your names.
        </p>
        <p className="pain-cause">
          <span className="pain-logos">🔁</span>so you end up retyping the same things all day.
        </p>
      </div>
      <div className="pains-fix">
        <Logo className="logo" width="64" height="55" aria-hidden="true" />
        <p>
          <b>with voicey, just talk.</b>
          <span>you get text that sounds like you, spelled your way.</span>
        </p>
        <a className="pill pains-fix-go" href={DOWNLOAD_URL}>
          <AppleLogoIcon02 aria-hidden="true" /> download for mac
        </a>
      </div>
    </section>
  );
}
