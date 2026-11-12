# Noise Diary

An iPhone app for keeping the noise diary that UK councils and landlords ask for
before they investigate a complaint about a neighbour.

Most councils ask you to log noise for at least two weeks. If your council has not
signed up to an online noise service, you are usually given paper diary sheets and
end up with voice memos and notes that do not match the form. Noise Diary keeps
everything in one place and prints it out the way the council expects.

## What it does

- **One-tap entry.** Tap *Record noise*. The start time is stamped straight away,
  a short audio clip (up to 2 minutes) records, and a live meter shows a relative
  sound level while it does.
- **The fields councils ask for.** Type of noise, where it came from, how long it
  lasted and how it affected you, plus free-text notes. Your last type of noise and
  source are remembered for the next entry.
- **Add an entry after the fact.** *Add earlier* writes up noise that already
  happened, with a time you choose and no recording. These entries are marked
  *Added later* in the app and in the PDF, along with when they were written.
- **Calendar and list views.** The Diary tab lists entries by day with daily totals;
  the Calendar tab shows a month at a glance. The Totals tab breaks a period
  (7, 14, 30 days or everything) down by day, by time of day (night is 23:00–07:00)
  and by type of noise.
- **Export for the council.** Pick a date range and get an A4 PDF laid out like a
  council diary sheet (date, time started, time finished, type of noise, where it
  came from, how it affected you, and a signature line), plus the audio clips,
  named to match the numbered rows, through the iOS share sheet.
- **Private.** Everything stays on the phone. An optional Face ID (or passcode) lock
  hides the diary whenever you leave the app.

The sound level is relative (0–100, from the microphone's reading). It is not a
calibrated decibel measurement and the app never presents it as one.

## Install

Noise Diary is distributed through TestFlight while in testing and then on the
App Store. Open the TestFlight invite link on your iPhone (iOS 17 or later), or
search for *Noise Diary* on the App Store once it is released.

## Where data lives

- Entries are stored with SwiftData in the app's own container on the iPhone.
- Audio clips are `.m4a` files in the app's `Application Support/Recordings` folder.
- Export files are written to the app's temporary folder and replaced on the
  next export.
- Your name and addresses for the PDF header are kept in the app's settings.

Deleting the app deletes the diary and recordings. Export before you do.
iCloud/iTunes device backups include the app's data like any other app.

## Privacy

Nothing leaves the phone unless you export it yourself through the share sheet.
There are no accounts, no servers, no analytics and no tracking. The app asks for:

- **Microphone**, only to record a clip when you tap *Record noise*. There is no
  background or continuous recording.
- **Face ID**, only if you turn on the lock.

## Building

The Xcode project is generated from `ios/project.yml` with XcodeGen; CI in
`.github/workflows/ios.yml` builds it and uploads to TestFlight. Sources are in
`ios/App/`:

- `Model/` – the SwiftData model and the plain `NoiseRecord` value type.
- `Logic/` – formatting, totals, calendar layout, file storage, PDF and export.
- `Services/` – audio recording and playback, and the app lock.
- `Views/` – SwiftUI screens.
