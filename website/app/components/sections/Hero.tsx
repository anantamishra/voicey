import { DOWNLOAD_URL } from "../../lib/links";
import AppleLogoIcon from "../icons/shared/AppleLogoIcon";
import HeroLogo from "../icons/Hero/HeroLogo";
import LockFilledIcon from "../icons/Hero/LockFilledIcon";

export default function Hero() {
  return (
    <section className="hero wrap">
      <h1 className="hero-title">
        <span className="hero-meet">meet</span>
        <span className="hero-tile" aria-hidden="true">
          <HeroLogo className="logo" width="40" height="34" aria-hidden="true" />
        </span>
        <span>
          <em>voicey</em>.
        </span>
      </h1>
      <p className="lede">
        <strong>talk</strong> instead of typing, <mark>anywhere</mark> on your mac.
      </p>
      <a className="pill pill-dark" href={DOWNLOAD_URL}>
        <AppleLogoIcon className="apple-logo" width="17" height="17" aria-hidden="true" /> download for mac
      </a>
      <p className="fine">free &amp; open source &middot; macos 13 or later &middot; apple silicon</p>
      <p className="fine fine-lock">
        <LockFilledIcon aria-hidden="true" />
        your voice stays on your mac
      </p>
    </section>
  );
}
