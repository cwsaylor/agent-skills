# App Store: screenshots, previews, badge, featuring

Source: Apple Developer News "Prepare and submit your apps for iPhone Duo"
(October 5, 2026) and the App Store Connect screenshot specifications.

## Dates

| Date | What |
|---|---|
| October 23, 2026 | iPhone Duo on sale |
| April 2027 | iPhone Duo screenshots **required** for any app submitted with the iOS 27.1 SDK or later |

## Screenshot specifications

Up to 10 per device size; JPEG or PNG; **no alpha channel or transparency**
(an RGBA PNG is rejected even at the right size).

| Display | Portrait | Landscape |
|---|---|---|
| iPhone Duo outer display | 1398 × 2034 | 2034 × 1398 |
| iPhone Duo inner display | 2007 × 2853 | 2853 × 2007 |

Submitting iPhone Duo screenshots makes the product page show a badge that the
app is optimized for iPhone Duo. Show the app across orientations and, where
it adds something, across poses (book, tabletop).

App previews have their own specification page in App Store Connect Help
("App preview specifications"). Check it for Duo dimensions before encoding.

## Workflow

1. Build with the iOS 27.1 SDK and finish the readiness steps first. The badge
   signals optimization; shipping it with a letterboxed app invites one-star
   reviews.
2. Capture on the iPhone Duo simulator:
   `xcrun simctl io booted screenshot name.png` in each pose and orientation,
   then crop or frame to the sizes above. Strip alpha:
   `sips -s format jpeg in.png --out out.jpg` or export PNG without alpha.
3. Upload under the iPhone Duo device sizes in App Store Connect.
4. Use the **preview tool** in App Store Connect to see how screenshots,
   product-page headers, search assets, and other metadata render on iPhone
   Duo. Design guidance and templates: developer.apple.com/app-store/asset-best-practices/.
5. Submit a **featuring nomination** (App Store Connect → Featuring
   Nominations). In "Helpful Details", state that the app is optimized for
   iPhone Duo and whether it supports **all device poses**. Guide:
   developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/.

## Release notes

Mention iPhone Duo support in the version's "What's New". Reviewers and the
editorial team read it.
