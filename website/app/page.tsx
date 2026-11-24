import Interactions from "./components/Interactions";
import Footer from "./components/layout/Footer";
import Nav from "./components/layout/Nav";
import TipToast from "./components/layout/TipToast";
import Download from "./components/sections/Download";
import DictationStory from "./components/sections/DictationStory";
import EveryApp from "./components/sections/EveryApp";
import Faq from "./components/sections/Faq";
import Features from "./components/sections/Features";
import Gestures from "./components/sections/Gestures";
import Hero from "./components/sections/Hero";
import HowItWorks from "./components/sections/HowItWorks";
import MakerNote from "./components/sections/MakerNote";
import Pricing from "./components/sections/Pricing";
import Typing from "./components/sections/Typing";
import VoiceStatement from "./components/sections/VoiceStatement";
import WhyVoicey from "./components/sections/WhyVoicey";

export default function Home() {
  return (
    <>
      <div />
      <div className="u-56a469">
        <Nav />
        <main id="top">
          <Hero />
          <DictationStory />
          <EveryApp />
          <HowItWorks />
          <VoiceStatement />
          <Gestures />
          <Typing />
          <WhyVoicey />
          <Features />
          <MakerNote />
          <Pricing />
          <Faq />
          <Download />
        </main>
        <TipToast />
        <Footer />
      </div>
      <Interactions />
    </>
  );
}
