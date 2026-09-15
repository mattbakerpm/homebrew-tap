cask "filler-killer" do
  version "1.6.0"
  sha256 "e0d68b4e48b10cdfffa88c78e10312130b9fd7978b8acf069332d0820755f4f4"

  url "https://github.com/mattbakerpm/filler-killer/releases/download/v#{version}/FillerKiller-#{version}.zip"
  name "Filler Killer"
  desc "Local real-time filler-word counter overlay for macOS (offline STT)"
  homepage "https://github.com/mattbakerpm/filler-killer"

  depends_on macos: :ventura

  app "FillerKiller.app"

  zap trash: [
    "~/Library/Application Support/FillerKiller",
  ]

  caveats <<~EOS
    Signed and notarized — no Gatekeeper override needed.
    Allow the Microphone prompt on first launch.
  EOS
end
