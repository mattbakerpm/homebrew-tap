class FillerKiller < Formula
  desc "Local real-time filler-word counter overlay for macOS (offline STT)"
  homepage "https://github.com/mattbakerpm/filler-killer"
  url "https://github.com/mattbakerpm/filler-killer/archive/refs/tags/v1.4.3.tar.gz"
  sha256 "eea8876f015609c55d09a7f336315e737e9a7c20b8b1f10b73b974afd58557ea"
  license "MIT"

  depends_on "python@3.13"
  depends_on :macos

  resource "vosk-model" do
    url "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"
    sha256 "30f26242c4eb449f948e42cb302dd7a686cb29a3423a8367f99ff41780942498"
  end

  def install
    libexec.install "coach.py", "config.json", "assets"

    # dedicated venv against brew's python (wheels: vosk, sounddevice, pyobjc)
    system Formula["python@3.13"].opt_bin/"python3.13", "-m", "venv", libexec/"venv"
    system libexec/"venv/bin/pip", "install", "--quiet",
           "vosk", "sounddevice", "audioop-lts", "pyobjc-framework-Cocoa",
           "pyobjc-framework-AVFoundation"

    resource("vosk-model").stage do
      src = Dir.exist?("vosk-model-small-en-us-0.15") ? "vosk-model-small-en-us-0.15" : "."
      (libexec/"model").install Dir["#{src}/*"]
    end

    # CLI launcher — always passes --dock so a running `filler-killer` shows
    # a Dock icon / Cmd-Tab entry too, matching the bundled .app below.
    (bin/"filler-killer").write <<~EOS
      #!/bin/bash
      export FILLER_KILLER_CONFIG="${HOME}/Library/Application Support/FillerKiller/config.json"
      export FILLER_KILLER_MODEL="#{libexec}/model"
      exec "#{libexec}/venv/bin/python" "#{libexec}/coach.py" --dock "$@"
    EOS

    # Deploys the FillerKiller.app built in post_install (below) into
    # /Applications. This can't happen automatically during `brew install`:
    # Homebrew's build sandbox blocks writes outside the Cellar/prefix, so
    # `ditto ... /Applications/...` fails with "Operation not permitted"
    # (confirmed empirically) — writing into /Applications is specifically
    # what Casks exist for, off-limits to a plain Formula's install process.
    # This script runs later, as a normal unsandboxed user command, so it
    # can do the copy. References opt_libexec, so it keeps deploying whatever
    # is current across `brew upgrade` without needing to change.
    (bin/"filler-killer-install-app").write <<~EOS
      #!/bin/bash
      set -euo pipefail
      SRC="#{opt_libexec}/FillerKiller.app"
      if [ ! -d "$SRC" ]; then
        echo "FillerKiller.app wasn't built — this needs Xcode Command Line Tools." >&2
        echo "Run: xcode-select --install    then: brew reinstall filler-killer" >&2
        exit 1
      fi
      pkill -f "FillerKiller.app/Contents/MacOS/FillerKiller" 2>/dev/null || true
      sleep 1
      rm -rf /Applications/FillerKiller.app
      ditto "$SRC" /Applications/FillerKiller.app
      tccutil reset Microphone local.fillerkiller >/dev/null 2>&1 || true
      echo "Installed. Launch \\"Filler Killer\\" from Launchpad, Spotlight, or the Dock."
      open -a /Applications/FillerKiller.app
    EOS
  end

  # Builds FillerKiller.app inside this keg (libexec) — everything Homebrew's
  # sandbox permits: icon, Info.plist, compiled launcher, codesign. Deploying
  # it into /Applications happens in `filler-killer-install-app` above,
  # because that step is sandbox-blocked here (see its comment).
  #
  # The bundle's launcher references THIS keg's venv/model/coach.py via the
  # version-independent opt_libexec symlink (kept current across `brew
  # upgrade`) rather than duplicating ~135MB into a second copy.
  def post_install
    unless quiet_system("xcrun", "--find", "swiftc")
      opoo "Xcode Command Line Tools not found (needed to build the Dock app) " \
           "— run `xcode-select --install`, then `brew reinstall filler-killer`. " \
           "`filler-killer` from the terminal works fully without it."
      return
    end

    app = libexec/"FillerKiller.app"
    rm_rf app
    (app/"Contents/MacOS").mkpath
    (app/"Contents/Resources").mkpath

    Dir.mktmpdir do |t|
      tmp = Pathname.new(t)

      # icon: brand mark rendered onto a white rounded tile
      system libexec/"venv/bin/python", "-c", <<~PYEOS
        from Cocoa import (NSImage, NSMakeRect, NSColor, NSBezierPath,
                           NSMakeSize, NSBitmapImageRep, NSPNGFileType,
                           NSCompositingOperationSourceOver)
        mark = NSImage.alloc().initWithContentsOfFile_("#{libexec}/assets/filler-killer-mark.svg")
        S = 1024
        img = NSImage.alloc().initWithSize_(NSMakeSize(S, S))
        img.lockFocus()
        NSColor.colorWithCalibratedRed_green_blue_alpha_(0.98, 0.98, 0.97, 1.0).setFill()
        NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(
            NSMakeRect(64, 64, S - 128, S - 128), 180, 180).fill()
        inset = 140
        mark.drawInRect_fromRect_operation_fraction_(
            NSMakeRect(inset, inset, S - 2 * inset, S - 2 * inset),
            NSMakeRect(0, 0, mark.size().width, mark.size().height),
            NSCompositingOperationSourceOver, 1.0)
        img.unlockFocus()
        rep = NSBitmapImageRep.imageRepWithData_(img.TIFFRepresentation())
        png = rep.representationUsingType_properties_(NSPNGFileType, None)
        png.writeToFile_atomically_("#{tmp}/icon.png", True)
      PYEOS

      iconset = tmp/"FillerKiller.iconset"
      iconset.mkpath
      [16, 32, 128, 256, 512].each do |sz|
        system "sips", "-z", sz.to_s, sz.to_s, (tmp/"icon.png").to_s,
               "--out", (iconset/"icon_#{sz}x#{sz}.png").to_s
        dbl = sz * 2
        system "sips", "-z", dbl.to_s, dbl.to_s, (tmp/"icon.png").to_s,
               "--out", (iconset/"icon_#{sz}x#{sz}@2x.png").to_s
      end
      system "iconutil", "-c", "icns", iconset.to_s,
             "-o", (app/"Contents/Resources/AppIcon.icns").to_s

      (app/"Contents/Info.plist").write <<~PLIST
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleName</key><string>FillerKiller</string>
          <key>CFBundleDisplayName</key><string>Filler Killer</string>
          <key>CFBundleIdentifier</key><string>local.fillerkiller</string>
          <key>CFBundleVersion</key><string>#{version}</string>
          <key>CFBundlePackageType</key><string>APPL</string>
          <key>CFBundleExecutable</key><string>FillerKiller</string>
          <key>CFBundleIconFile</key><string>AppIcon</string>
          <key>NSMicrophoneUsageDescription</key>
          <string>Filler Killer listens to your microphone locally to count filler words. Audio never leaves this Mac.</string>
          <key>NSHighResolutionCapable</key><true/>
        </dict>
        </plist>
      PLIST

      # A shell script that exec's python breaks microphone TCC (at mic-access
      # time the process identity becomes bare python, which has no usage
      # description, so macOS silently auto-denies without ever prompting).
      # A compiled binary that runs python as a CHILD keeps FillerKiller.app
      # as the responsible process, so the mic prompt appears correctly.
      # Paths point at opt_libexec (the version-independent symlink) so this
      # binary keeps working across `brew upgrade` without needing a rebuild.
      swift_src = tmp/"launcher.swift"
      template = <<~'SWIFT'
        import Foundation
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "__PYTHON_BIN__")
        proc.arguments = ["__COACH_PY__", "--dock"]
        signal(SIGTERM, SIG_IGN)
        let sigSrc = DispatchSource.makeSignalSource(signal: SIGTERM)
        sigSrc.setEventHandler { proc.terminate() }
        sigSrc.resume()
        do {
            try proc.run()
        } catch {
            FileHandle.standardError.write("launch failed: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
        proc.waitUntilExit()
        exit(proc.terminationStatus)
      SWIFT
      swift_src.write(
        template
          .sub("__PYTHON_BIN__", "#{opt_libexec}/venv/bin/python")
          .sub("__COACH_PY__", "#{opt_libexec}/coach.py")
      )
      system "swiftc", "-O", swift_src.to_s, "-o", (app/"Contents/MacOS/FillerKiller").to_s
    end

    system "codesign", "--force", "--sign", "-", app.to_s
  end

  def caveats
    <<~EOS
      Launch from the terminal:
        filler-killer

      For a real Dock app (Launchpad, Spotlight, double-click, "Keep in
      Dock"), run this once after installing:
        filler-killer-install-app
      It stays working across `brew upgrade` without needing to be re-run
      (only re-run it if you want the icon/version metadata refreshed).
      Needs Xcode Command Line Tools to build; if missing, `filler-killer`
      from the terminal still works fully — install CLT and
      `brew reinstall filler-killer` to get the Dock app too.

      Both share this formula's install. Settings:
        ~/Library/Application Support/FillerKiller/config.json

      First launch (either one): macOS will ask for Microphone access.

      Note: `brew uninstall` can't remove /Applications/FillerKiller.app —
      delete it yourself if you want it gone:
        rm -rf /Applications/FillerKiller.app
    EOS
  end

  test do
    assert_match "usage", shell_output("#{bin}/filler-killer --help")
  end
end
