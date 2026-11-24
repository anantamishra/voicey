import { DOWNLOAD_URL } from "../../lib/links";
import AppleLogoIcon from "../icons/shared/AppleLogoIcon";

const INSTALL = "curl -fsSL https://raw.githubusercontent.com/anantamishra/voicey/main/install.sh | bash";

export default function Download() {
  return (
    <section id="download" className="ending wrap">
      <h2>
        stop typing.
        <br />
        start <em>talking</em>.
      </h2>
      <p className="body">press a key, say it, and it&rsquo;s written for you.</p>
      <a className="pill pill-dark" href={DOWNLOAD_URL}>
        <AppleLogoIcon className="apple-logo" width="17" height="17" aria-hidden="true" /> download for mac
      </a>
      <p className="fine">free &amp; open source &middot; macos 13 or later &middot; apple silicon</p>
      <div className="v-install">
        <code>{INSTALL}</code>
        <button type="button" className="v-copy" data-copy={INSTALL}>
          copy
        </button>
      </div>
      <p className="fine">or paste this in terminal. it installs without the &ldquo;could not verify&rdquo; warning.</p>
    </section>
  );
}
