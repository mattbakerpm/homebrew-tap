cask "filler-killer" do
  version "1.6.0"
  sha256 "8514ed1ee33475b4c0bf794ece0e08ed41140031df3dad6b6b9caf925dffcbd9"

  url "https://github.com/mattbakerpm/filler-killer/releases/download/v#{version}/FillerKiller-#{version}.zip"
  name "Filler Killer"
  desc "Local real-time filler-word counter overlay for macOS (offline STT)"
  homepage "https://github.com/mattbakerpm/filler-killer"

  depends_on macos: ">= :ventura"

  app "FillerKiller.app"

  zap trash: [
    "~/Library/Application Support/FillerKiller",
  ]

  caveats <<~EOS
    Signed and notarized — no Gatekeeper override needed.
    Allow the Microphone prompt on first launch.
  EOS
end
