class FillerKiller < Formula
  desc "Local real-time filler-word counter overlay for macOS (offline STT)"
  homepage "https://github.com/mattbakerpm/filler-killer"
  url "https://github.com/mattbakerpm/filler-killer/archive/refs/tags/v1.4.2.tar.gz"
  sha256 "49ddd56b8afb468f66b3e10f5cce073d4f3e6030a4f2f3b8b277c7ffa0d926fc"
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

    (bin/"filler-killer").write <<~EOS
      #!/bin/bash
      export FILLER_KILLER_CONFIG="${HOME}/Library/Application Support/FillerKiller/config.json"
      export FILLER_KILLER_MODEL="#{libexec}/model"
      exec "#{libexec}/venv/bin/python" "#{libexec}/coach.py" "$@"
    EOS
  end

  def caveats
    <<~EOS
      Launch the floating overlay with:
        filler-killer

      First run: macOS will ask for Microphone access (attributed to your
      terminal). Settings live in:
        ~/Library/Application Support/FillerKiller/config.json

      For a Dock app instead, clone the repo and run ./make_app.sh --install
    EOS
  end

  test do
    assert_match "usage", shell_output("#{bin}/filler-killer --help")
  end
end
