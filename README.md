# Psiphon stuff to be filed later

### Adding a new language

When `transifex_pull.py` finds a new language that has crossed the desired threshold, it'll pull the corresponding `.strings` files. But those files won't have an effect in the app without two modifications:

1. **Add the language to the Xcode project.** In the *Project* settings, *Info* tab. Click `+` and select the desired language (if it's not in the list, then it can't be added here -- skip to step 2). Allow it to create the English files (you'll need to re-pull the translations, as they'll get clobbered). Note that the directory Xcode creates is the one that must be used -- if it doens't match the directory created by `transifex_pull`, then the pull script will need to be modified to map to the correct language code.

2. **Add the language to our in-app language selector.** In `Root.inApp.plist`, add the new language code and the name of the language as it's written in that language. If the language is not one of our top 3 or 4, it should be added in alphabetical order, based on the language code.

Do some testing. Commit.


###Endless

A (Mobile)Safari-like web browser for iOS (wrapping around UIWebView, of
course) with a design goal of increased security and privacy.

Current builds are available for free in the
[App Store](https://itunes.apple.com/us/app/endless-browser/id974745755?mt=8).

Please see the [LICENSE](https://github.com/jcs/endless/blob/master/LICENSE)
file for redistribution terms.  Redistribution of this software in binary
form, with or without modification, is not permitted.

#####Screenshots

![https://i.imgur.com/8FgHAWZ.png](https://i.imgur.com/8FgHAWZ.png) ![https://i.imgur.com/evQ63JX.png](https://i.imgur.com/evQ63JX.png)

#####Basic browser functionality implemented:

- Basics of entering URLs, following redirections, back, forward, cookie
  storage, HTTP basic authentication

- Multiple tabs with support for `window.open()` and `<a target="_blank">`
  automatically opening new tab windows, but blocks calls not made via user
  interaction events (similar to most desktop browser popup blockers)

- Bookmark list with management, re-ordering, and editing

- Custom long-press menu for links to open in a new tab, and to save images
  to the device; shows image or link alt text (useful for sites like
  [xkcd](http://xkcd.com/))

- Swipe left and right to go back and forward

- Search from URL bar with DDG, Google, or Startpage

- Optional dark/night-time interface

#####Security and privacy-focused features implemented:

- Per-host/domain security and privacy settings:

  - Disables SSL 2 and SSL 3 by default with a configurable minimum TLS
    version to require from the host, such as TLS 1.2-only.  Also disables
    weak TLS ciphers.

  - Configurable security policy:

    - Open (default, normal browsing mode)

    - No after-load connections (blocks XMLHTTPRequest/AJAX requests,
      WebSockets, and \<video\> and \<audio\> elements)

    - Strict (blocks all of the above plus embedded fonts and Javascript)

  - Blocks mixed-content requests (http elements on an https page) unless
    disabled (useful for RSS readers), shows broken padlock

  - Blocks pages loaded from non-local networks (i.e., the internet) from
    trying to load sub-requests (e.g., images, iframes, ajax) from hosts that
    are on local RFC6890 networks such as routers and other insecure devices

  - Defaults to only accepting cookies and local storage for the duration of
    the session (until the last tab accessing that data closes) but allows
    persistent storage from configured hosts

- Auto-destroys non-whitelisted cookies and local storage (even within the same
  tab) that has not been accessed by any other tab within a configurable amount
  of time (defaults to 30 minutes) to improve privacy while browsing within a
  long-running tab

- Cookie and localStorage database listing and deletion per-host

- Integrated full [HTTPS Everywhere](https://www.eff.org/HTTPS-EVERYWHERE)
  ruleset to do on-the-fly URL rewriting to force requests over SSL where
  supported, including setting the secure bit on received cookies and
  auto-detection of redirection loops

- HTTP Strict Transport Security (RFC6797) implementation (in addition to
  WebKit's mystery built-in one) with Chromium's large preload list

- Integrated URL blocker with a small included ruleset of behavior-tracking
  advertising, analytics, and social networking widgets (this list is intended
  for enhancing privacy and not to be an AdBlock-style comprehensive ad-blocking
  list)

- Shows locked padlock for fully SSL-encrypted URLs, and organization name for
  sites with EV SSL certs

- Integrated SSL certificate viewer by tapping on padlock icon, highlighting
  weak SSL certificate signature algorithms and showing per-connection
  negotiated TLS/SSL protocol version and cipher information

- Optional sending of Do-Not-Track header on all requests

- Integrated [1Password button](https://github.com/AgileBits/onepassword-app-extension)
  to autofill website logins, passwords, credit card numbers, etc.; requires
  the 1Password iOS app to be installed (and is not enabled if not installed)
