#!/bin/bash
# Prints a one-item Sparkle appcast for a release archive.
#   scripts/appcast.sh <archive> <download-url> [notes]
# Version and minimum macOS come from Info.plist; the EdDSA signature is made
# by Sparkle's sign_update with the private key in the login Keychain.
set -euo pipefail
cd "$(dirname "$0")/.."

archive="$1"; url="$2"; notes="${3:-}"
plist() { /usr/libexec/PlistBuddy -c "Print $1" Info.plist; }
signature="$(.build/artifacts/sparkle/Sparkle/bin/sign_update "$archive")"

cat <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Podflow</title>
    <item>
      <title>Podflow $(plist CFBundleShortVersionString)</title>
      <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <sparkle:version>$(plist CFBundleVersion)</sparkle:version>
      <sparkle:shortVersionString>$(plist CFBundleShortVersionString)</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$(plist LSMinimumSystemVersion)</sparkle:minimumSystemVersion>
      <description><![CDATA[${notes}]]></description>
      <enclosure url="${url}" ${signature} type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
