import KeyIcon from "../icons/BigFiles/KeyIcon";
import PaletteIcon from "../icons/BigFiles/PaletteIcon";
import DocumentIcon from "../icons/EveryKindOfWork/DocumentIcon";
import MicrophoneIcon from "../icons/EveryKindOfWork/MicrophoneIcon";
import SoundIcon from "../icons/EveryKindOfWork/SoundIcon";
import TextIcon from "../icons/EveryKindOfWork/TextIcon";
import CopyIcon from "../icons/HowItWorks/CopyIcon";
import DotsGridIcon from "../icons/HowItWorks/DotsGridIcon";
import GlobeOutlineIcon from "../icons/HowItWorks/GlobeOutlineIcon";
import LaptopIcon from "../icons/HowItWorks/LaptopIcon";
import LockKeyIcon from "../icons/HowItWorks/LockKeyIcon";
import RefreshIcon from "../icons/HowItWorks/RefreshIcon";
import SparkleIcon from "../icons/shared/SparkleIcon";

const ICON = { width: 24, height: 24, "aria-hidden": true } as const;

export default function HowItWorks() {
  return (
    <section id="how" className="notes wrap">
      <div className="note">
        <p className="note-head">
          <span className="badge">1</span> what it is
        </p>
        <p className="note-lead">talk instead of typing, in every app on your mac.</p>
        <p>
          press a key and talk. the text appears where your cursor is: in mail, messages, notes, your code editor, anywhere you can
          type.
        </p>
        <p>
          voicey takes out the &ldquo;um&rdquo;s, fixes the punctuation and spells your names right, using the ai tool you already
          have.
        </p>
        <p>
          <strong>your voice never leaves your mac.</strong> only the words do, and only if you let them.
        </p>
      </div>

      <div className="note">
        <p className="note-head">
          <span className="badge">2</span> why it&rsquo;s different
        </p>
        <div className="vs">
          <div>
            <b>most dictation</b>
            <p>sends your audio to a server, or writes a raw transcript with every &ldquo;um&rdquo; and a misspelled name.</p>
          </div>
          <div className="us">
            <b>voicey</b>
            <p>
              turns speech into text on your mac with whisper, then asks claude or codex to tidy it. it knows your names, your
              snippets and the tone for each app.
            </p>
          </div>
        </div>
        <div className="facts">
          <div>
            <b>0 bytes</b>
            <span>of your voice uploaded</span>
          </div>
          <div>
            <b>1 key</b>
            <span>to start, stop or lock</span>
          </div>
          <div>
            <b>free</b>
            <span>and open source (mit)</span>
          </div>
        </div>
      </div>

      <div className="note">
        <p className="note-head">
          <span className="badge">3</span> how it works
        </p>
        <ol className="steps how-steps">
          <li>
            <span className="step-body">
              <b>install voicey</b>
              <span>it lives in your dock and menu bar.</span>
            </span>
          </li>
          <li>
            <span className="step-body">
              <b>press your shortcut and talk</b>
              <span>
                <kbd>⌃</kbd>
                <kbd>⌥</kbd>
                <kbd>space</kbd> by default, or any key you choose. hold it, tap it, or double-tap for hands-free.
              </span>
            </span>
          </li>
          <li>
            <span className="step-body">
              <b>let go</b>
              <span>the polished text lands at your cursor.</span>
            </span>
          </li>
        </ol>
        <p className="note-foot">
          the first launch takes about a minute: voicey asks for permissions, finds your ai tools and downloads the speech model.
        </p>
      </div>

      <div className="note">
        <p className="note-head">
          <span className="badge">4</span> what you get
        </p>
        <div className="feature-groups">
          <div className="fg">
            <p className="fg-head">talk your way</p>
            <ul className="feature-list">
              <li>
                <MicrophoneIcon {...ICON} />
                hold to talk, tap to toggle, or double-tap for hands-free
              </li>
              <li>
                <KeyIcon {...ICON} />
                any key as your shortcut, even fn
              </li>
              <li>
                <SoundIcon {...ICON} />a live pop-up shows your words as you speak
              </li>
              <li>
                <GlobeOutlineIcon {...ICON} />
                many languages, with the multilingual models
              </li>
            </ul>
          </div>
          <div className="fg">
            <p className="fg-head">write like you</p>
            <ul className="feature-list">
              <li>
                <SparkleIcon {...ICON} />
                ai polish with claude code or codex
              </li>
              <li>
                <DocumentIcon {...ICON} />a personal dictionary for names and jargon
              </li>
              <li>
                <PaletteIcon {...ICON} />a different tone for each app
              </li>
              <li>
                <TextIcon {...ICON} />
                snippets: say &ldquo;my address&rdquo;, get the full text
              </li>
            </ul>
          </div>
          <div className="fg">
            <p className="fg-head">private and simple</p>
            <ul className="feature-list">
              <li>
                <LockKeyIcon {...ICON} />
                your voice never leaves your mac
              </li>
              <li>
                <CopyIcon {...ICON} />
                copy your last transcription from the menu bar
              </li>
              <li>
                <DotsGridIcon {...ICON} />
                setup finds your ai tools, and can install them
              </li>
              <li>
                <RefreshIcon {...ICON} />
                updates itself, in the background
              </li>
              <li>
                <LaptopIcon {...ICON} />a normal mac app, in your dock and menu bar
              </li>
            </ul>
          </div>
        </div>
      </div>
    </section>
  );
}
