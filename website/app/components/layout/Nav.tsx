export default function Nav() {
  return (
    <nav className="nav" aria-label="Main">
      <a href="#top" className="nav-home on" aria-current="location">
        voicey
      </a>
      <a href="#how">how it works</a>
      <a href="#features">features</a>
      <a href="#pricing">free</a>
      <a href="#faq">faq</a>
      <a className="nav-account" href="https://github.com/anantamishra/voicey" target="_blank" rel="noopener noreferrer">
        github
      </a>
    </nav>
  );
}
