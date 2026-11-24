export default function Faq() {
  return (
    <section id="faq" className="section wrap centered">
      <h2>
        questions, <em>answered</em>.
      </h2>
      <div className="faq">
        <details>
          <summary>what is voicey?</summary>
          <p>a mac app that turns your voice into text, anywhere you can type. press a key, talk, and the polished text appears at your cursor, in mail, messages, notes, your editor, anywhere.</p>
        </details>
        <details>
          <summary>is my voice uploaded anywhere?</summary>
          <p>no. your speech is turned into text on your mac, with whisper, or with apple’s own recognizer if you prefer. the audio never leaves your computer.</p>
        </details>
        <details>
          <summary>what does the ai polish do, and do i need it?</summary>
          <p>it fixes punctuation and filler words like “um”, corrects misheard names using your dictionary, and can match the tone of the app you’re in. it’s optional. turn it off and you get the plain transcript, and nothing at all is sent anywhere.</p>
        </details>
        <details>
          <summary>which ai tools does it use?</summary>
          <p>claude code and codex, using your own login with them. voicey finds them on your mac when you set it up, can install either with one click, and has a test button to check it works. only the transcript text is sent to the one you pick.</p>
        </details>
        <details>
          <summary>does it work offline?</summary>
          <p>the speech-to-text part does, once the speech model has downloaded. ai polish needs whatever internet access your ai tool needs. if you turn polish off, voicey works fully offline.</p>
        </details>
        <details>
          <summary>which apps does it work in?</summary>
          <p>any app with a text field. voicey pastes the text where your cursor is, which is why it asks for the accessibility permission. without it, voicey still copies the text and you paste it yourself.</p>
        </details>
        <details>
          <summary>what’s the shortcut, and can i change it?</summary>
          <p>the default is ⌃⌥ space. record any key you like in settings, even a single key such as fn, right ⌥ or an f-key. hold it to talk, press it once to start and again to stop, or double-tap it for hands-free dictation.</p>
        </details>
        <details>
          <summary>can i start it without touching the keyboard?</summary>
          <p>yes. turn on “double clap to start” in settings, then clap twice and talk. it’s off by default, because it keeps the microphone open to listen for claps (nothing is recorded or saved, and the orange mic dot stays on). a double clap starts hands-free dictation.</p>
        </details>
        <details>
          <summary>does it stop by itself when i finish talking?</summary>
          <p>yes. after you’ve spoken, a few quiet seconds (3 by default, or 2 or 5, or never) end the recording and voicey transcribes and pastes the text. you can still stop it any time with your shortcut or the menu.</p>
        </details>
        <details>
          <summary>which languages does it understand?</summary>
          <p>many. pick a multilingual whisper model in settings, or use apple’s recognizer, and choose your language. the english-only models are smaller and faster if english is all you need.</p>
        </details>
        <details>
          <summary>what does it cost?</summary>
          <p>
            nothing. voicey is free and open source under the mit license. the code is on{" "}
            <a className="v-link" href="https://github.com/anantamishra/voicey" target="_blank" rel="noopener noreferrer">
              github
            </a>
            .
          </p>
        </details>
        <details>
          <summary>why does macos say it can’t verify voicey?</summary>
          <p>voicey isn’t notarized by apple yet, so macos shows a warning for copies downloaded in a browser. open system settings, go to privacy & security and click open anyway. or install it with the terminal line on this page, which avoids the warning entirely.</p>
        </details>
        <details>
          <summary>which permissions does it need?</summary>
          <p>microphone, to hear you. speech recognition, for the live preview while you talk. and accessibility, to paste at your cursor and watch your shortcut. the setup screen explains each one.</p>
        </details>
        <details>
          <summary>what are the system requirements?</summary>
          <p>a mac with apple silicon running macos 13 or later. the built-in whisper engine needs a recent macos. on older versions voicey falls back to apple’s recognizer automatically.</p>
        </details>
        <details>
          <summary>how does it update?</summary>
          <p>voicey checks for new versions once a day. choose check for updates in the menu bar to look right away. updates are checked against a checksum before they’re installed.</p>
        </details>
        <details>
          <summary>where can i see the code or report a bug?</summary>
          <p>
            on github, at{" "}
            <a className="v-link" href="https://github.com/anantamishra/voicey" target="_blank" rel="noopener noreferrer">
              github.com/anantamishra/voicey
            </a>
            . issues and ideas are welcome.
          </p>
        </details>
      </div>
    </section>
  );
}
