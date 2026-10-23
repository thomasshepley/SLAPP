# TestFlight setup (all from the iPad)

You only do this once. Once it's done, every push to `main` that touches
`TitanDeck/` gets built on GitHub's macOS machines and lands in TestFlight on the
iPad. No Mac needed.

Allow about 30 minutes, plus however long Apple takes to approve the Developer
Program enrolment (usually within a day or two).

## 1. Join the Apple Developer Program

developer.apple.com/programs → Enroll, using the Apple ID you'll use on the iPad.
It's £79 a year. Wait for the "Welcome to the Apple Developer Program" email
before carrying on.

## 2. Note your Team ID

developer.apple.com/account → **Membership details** → **Team ID**. It's a
10-character code like `AB12CD34EF`. Keep it for step 6.

## 3. Register the app ID with the Stream Deck capability

developer.apple.com/account → **Certificates, Identifiers & Profiles** →
**Identifiers** → **+**

1. Choose **App IDs** → **App**.
2. Description: `TitanDeck`. Bundle ID: **Explicit**,
   `uk.co.elexproductions.titandeck`.
3. In the Capabilities list, tick **Communicates with Drivers**. This is the
   entitlement Stream Deck Kit needs. Without it the app runs, but the deck stays
   dark and Settings shows "Missing driver entitlement".
4. Continue → Register.

## 4. Create the app in App Store Connect

appstoreconnect.apple.com → **Apps** → **+** → **New App**

- Platform: iOS
- Name: anything unique on the App Store, e.g. `TitanDeck Elex`. Testers never
  see it. Only the on-device name ("TitanDeck") matters.
- Primary language: English (UK)
- Bundle ID: pick `uk.co.elexproductions.titandeck` from the list
- SKU: `titandeck`
- User access: Full access

Nothing here makes the app public. It only exists in TestFlight until you choose
to submit it for review, which you never need to do.

## 5. Create an App Store Connect API key

appstoreconnect.apple.com → **Users and Access** → **Integrations** → **App Store
Connect API** → **Team Keys** → **+** (you may need to request access the first
time; that's instant).

- Name: `GitHub TitanDeck`
- Access: **Admin**. CI needs this to create the signing certificate and
  provisioning profile for you. Lower roles can't.

Then note:

- **Issuer ID**, shown above the keys table
- **Key ID**, in the new key's row
- **Download** the key. You get `AuthKey_XXXXXXXXXX.p8`, and you can only
  download it **once**, so keep it somewhere safe in Files.

To copy the key's contents on the iPad: in Files, rename it to end in `.txt`,
open it, select all, copy. It starts with `-----BEGIN PRIVATE KEY-----` and ends
with `-----END PRIVATE KEY-----`, and you need both of those lines included.

## 6. Add four secrets to GitHub

github.com/thomasshepley/SLAPP → **Settings** → **Secrets and variables** →
**Actions** → **New repository secret**, once for each:

| Name | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Team ID from step 2 |
| `ASC_ISSUER_ID` | Issuer ID from step 5 |
| `ASC_KEY_ID` | Key ID from step 5 |
| `ASC_KEY_P8` | The whole contents of the `.p8` file from step 5 |

Secrets are write-only. Nobody (including me) can read them back out of GitHub.

## 7. Run the first build

github.com/thomasshepley/SLAPP → **Actions** → **TitanDeck** → **Run workflow**
→ leave "Upload this build to TestFlight" ticked → **Run workflow**.

(The Run workflow button only shows up once the TitanDeck PR is merged into
`main`.)

A run takes roughly 10-20 minutes. Then Apple processes the build for another
5-20 minutes and emails you when it's ready.

## 8. Install on the iPad

1. App Store Connect → your app → **TestFlight** → **Internal Testing** → **+**
   → create a group, add yourself.
2. Install **TestFlight** from the App Store on the iPad and sign in with the
   same Apple ID.
3. TitanDeck appears there. Tap Install.

New builds show up in TestFlight automatically after each push to `main`. Each
TestFlight build lasts 90 days, so there's no 7-day re-signing.

## 9. Stream Deck prerequisites on the iPad

- Install **Elgato Stream Deck Connect** from the App Store.
- Open it and follow its instructions to enable the Stream Deck driver in
  iPad Settings.
- Stream Deck Kit needs an iPad with USB-C and an M1 chip or newer.

## If the TestFlight job fails

The archive/sign step is the one part I couldn't run before handing it over,
because it needs your secrets. If it goes red, tell me and I'll fix it from the
log. The usual culprits:

- **"No profiles for 'uk.co.elexproductions.titandeck' were found"**: the API
  key isn't Admin (step 5), or the app ID from step 3 is missing.
- **Entitlement errors mentioning `driverkit`**: Communicates with Drivers
  isn't ticked on the app ID (step 3).
- **"No suitable application records were found"**: the app record from
  step 4 doesn't exist yet, or uses a different bundle ID.
