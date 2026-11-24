export default function VoiceStatement() {
  return (
    <section className="prose wrap">
      <h2>
        your voice stays home.
        <br />
        <span className="word-pill">zero</span> uploaded.
      </h2>
      <p>voicey turns your speech into text on your mac, with whisper. the audio is never sent anywhere.</p>
      <p>
        if you turn on ai polish, only the words go to the tool you chose, using your own login with it. turn it off and nothing
        leaves your mac at all.
      </p>
      <p className="flow">
        <span>speak</span>
        <i aria-hidden="true">→</i>
        <span>transcribe</span>
        <i aria-hidden="true">→</i>
        <span>paste</span>
      </p>
    </section>
  );
}
