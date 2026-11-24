/** Where the site sends people. Change an address here and every button follows. */
export const REPO_URL = "https://github.com/anantamishra/voicey";
export const PROFILE_URL = "https://github.com/anantamishra/";

/** Always the newest release's zip: the release process publishes a copy named Voicey.zip. */
export const DOWNLOAD_URL = `${REPO_URL}/releases/latest/download/Voicey.zip`;

/** Path to a file in public/, correct whether the site is hosted at the root or in a sub-folder. */
export const asset = (path: string) => `${process.env.NEXT_PUBLIC_BASE_PATH ?? ""}${path}`;
