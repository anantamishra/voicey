import { PROFILE_URL, REPO_URL as REPO } from "../../lib/links";
import Logo from "../icons/shared/Logo";


export default function Footer() {
  return (
    <footer className="foot">
      <p>
        <a href={REPO} target="_blank" rel="noopener noreferrer">github</a>
        <span aria-hidden="true">·</span>
        <a href={`${REPO}/releases/latest`} target="_blank" rel="noopener noreferrer">releases</a>
        <span aria-hidden="true">·</span>
        <a href={`${REPO}/blob/main/CHANGELOG.md`} target="_blank" rel="noopener noreferrer">changelog</a>
        <span aria-hidden="true">·</span>
        <a href={`${REPO}/blob/main/LICENSE`} target="_blank" rel="noopener noreferrer">mit license</a>
        <span aria-hidden="true">·</span>
        <a href={`${REPO}/issues`} target="_blank" rel="noopener noreferrer">report a bug</a>
        <span aria-hidden="true">·</span>© 2026 voicey
      </p>
      <p className="u-5422e1">
        made with ❤️ by{" "}
        <a className="v-link" href={PROFILE_URL} target="_blank" rel="noopener noreferrer">
          ananta mishra
        </a>
      </p>
      <a className="hero-title foot-mark" href="#top" aria-label="voicey, back to the top">
        <span className="hero-meet">meet</span>
        <span className="hero-tile" aria-hidden="true">
          <Logo className="logo" width="40" height="34" aria-hidden="true" />
        </span>
        <span>
          <em>voicey</em>.
        </span>
      </a>
    </footer>
  );
}
