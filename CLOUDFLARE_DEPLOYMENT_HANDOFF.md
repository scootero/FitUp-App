# FitOff Cloudflare deployment handoff

Cloudflare deployment has not occurred. App Store Connect has not been edited.

The website package is ready to upload after you choose to deploy. Do not treat a guessed pages.dev URL as live until Cloudflare assigns it.

## Package

- Website folder: `/Users/scott/Desktop/FitUp-App----DONE--off-icloud/FitOff-website-upload`
- ZIP: `/Users/scott/Desktop/FitUp-App----DONE--off-icloud/FitOff-website-upload.zip`
- ZIP layout opens directly to `index.html`, `support/`, `privacy/`, `terms/`, and `assets/`.

## Proposed Cloudflare project

- Project name: `fitoff`
- Expected pages.dev pattern if that name is available: `https://fitoff.pages.dev/`
- Cloudflare assigns the final subdomain. Do not assume the name is unused.
- Upload the ZIP contents, or the folder contents, as the site root. Do not upload this handoff as a public page.

## Routes to test after deploy

- `/`
- `/support/`
- `/privacy/`
- `/terms/`
- `/assets/styles.css`
- `/assets/fitoff-app-icon.png`

## Approved contact

- Public support and privacy email: `catsuit_corkers_1c@icloud.com`
- Mailto subjects in the website: `FitOff Support`, `FitOff Privacy`, `FitOff Account Deletion`, `FitOff Terms`
- No postal address or telephone number is published.

## Post-deployment action, required before the final App Store archive

After Cloudflare assigns the live Privacy URL, replace this in-app link before archiving and uploading the final App Store build:

- File: `FitUp/FitUp/FitUp/Views/Profile/ProfileView.swift`
- Current value: `https://scootero.github.io/FitUp-App/privacy/`
- Replace it with the final FitOff Cloudflare Privacy URL, including the `/privacy/` path.

Do not guess that URL before deployment. The app was intentionally left on the existing GitHub Pages address until the pages.dev address exists.

## In-app Privacy and Terms, waiting for approval

- Privacy: Profile → Privacy opens the GitHub Pages URL above. It is a working link, but it is not the future Cloudflare URL.
- Terms: there is no customer-facing Terms of Use link in Profile or on the FitOff Pro paywall.
- Do not add that link until approved. The approved destination is Apple’s standard EULA: `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`

Narrow plan, not implemented:

1. Add a Terms of Use text button on `PaywallView` near Restore Purchases, opening Apple’s standard EULA.
2. Add a Terms row in Profile next to Privacy, opening the same Apple EULA URL.
3. Leave the Profile Privacy URL unchanged until the Cloudflare Privacy URL is known.

## Branding check

The deployable website must not contain Pondera, Attune, the old Gmail address, owner-confirmation language, or the GitHub Pages privacy URL.

## Not done

Cloudflare has not been deployed. App Store Connect has not been edited.
