import { DOWNLOAD_URL, asset } from "../../lib/links";
import DocumentIcon from "../icons/EveryKindOfWork/DocumentIcon";
import MicrophoneIcon from "../icons/EveryKindOfWork/MicrophoneIcon";
import SoundIcon from "../icons/EveryKindOfWork/SoundIcon";
import GlobeOutlineIcon from "../icons/HowItWorks/GlobeOutlineIcon";
import LaptopIcon from "../icons/HowItWorks/LaptopIcon";
import RefreshCwIcon from "../icons/Pricing/RefreshCwIcon";
import LockIcon from "../icons/shared/LockIcon";
import SparkleIcon from "../icons/shared/SparkleIcon";

export default function Pricing() {
  return (
    <section id="pricing" className="section wrap centered">
      <h2>
        free. <em>really</em>.
      </h2>
      <p className="body">no plans, no accounts, no limits. voicey is open source under the mit license.</p>
      <div className="price-card">
        <div className="price-top">
          <div className="price-what">
            <span className="price-mood" aria-hidden="true">
              <img src={asset("/brand/voicey-icon.png")} alt="" className="on" />
            </span>
            <div>
              <p className="price-size">voicey</p>
              <p className="price-sub">for mac</p>
            </div>
          </div>
        </div>
        <div className="price-row">
          <div className="price-amount">
            <span className="price-number">$0</span>
            <span className="price-period">/forever</span>
            <p className="price-sub">open source · mit license</p>
          </div>
        </div>
        <ul className="price-list">
          <li>
            <LockIcon width="18" height="18" aria-hidden="true" />
            <span>your voice never leaves your mac</span>
          </li>
          <li>
            <MicrophoneIcon width="18" height="18" aria-hidden="true" />
            <span>hold, tap or double-tap, with any key</span>
          </li>
          <li>
            <MicrophoneIcon width="18" height="18" aria-hidden="true" />
            <span>double clap to start, and it stops when you pause</span>
          </li>
          <li>
            <SparkleIcon width="18" height="18" aria-hidden="true" />
            <span>
              ai polish with{" "}
              <span className="price-apps">
                <span className="price-app" title="Claude Code">
                  <img src={asset("/brands/apps/claude.png")} alt="Claude Code" />
                </span>
                <span className="price-app" title="Codex">
                  <img src={asset("/brands/apps/chatgpt.png")} alt="Codex" />
                </span>
              </span>
              claude code or codex
            </span>
          </li>
          <li>
            <DocumentIcon width="18" height="18" aria-hidden="true" />
            <span>a personal dictionary, snippets and per-app tone</span>
          </li>
          <li>
            <SoundIcon width="18" height="18" aria-hidden="true" />
            <span>a live pop-up shows your words as you speak</span>
          </li>
          <li>
            <GlobeOutlineIcon width="18" height="18" aria-hidden="true" />
            <span>many languages, with the multilingual models</span>
          </li>
          <li>
            <RefreshCwIcon width="18" height="18" aria-hidden="true" />
            <span>updates itself, in the background</span>
          </li>
          <li>
            <LaptopIcon width="18" height="18" aria-hidden="true" />
            <span>macos 13 or later, on apple silicon</span>
          </li>
        </ul>
        <a className="pill pill-dark price-go" href={DOWNLOAD_URL}>
          download for mac →
        </a>
      </div>
    </section>
  );
}
