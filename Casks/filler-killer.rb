cask "filler-killer" do
  version "1.6.0"
  sha256 "21b774d760522f931960ee1898bf87b13cb54c280cf742a25d866056db6d3044"

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
