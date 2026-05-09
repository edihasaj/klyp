cask "klyp" do
  version "0.1.4"
  sha256 "c8d40987cd94fae4ec5cec6e535b897b6e63cd1944a1f7db84a2eb9d220551d5"

  url "https://github.com/edihasaj/klyp/releases/download/v#{version}/Klyp.app.zip"
  name "Klyp"
  desc "Lightweight clipboard history manager for macOS"
  homepage "https://github.com/edihasaj/klyp"

  depends_on macos: ">= :sonoma"

  app "Klyp.app"

  zap trash: [
    "~/Library/Application Support/Klyp",
    "~/Library/Preferences/com.edihasaj.klyp.plist",
    "~/Library/Caches/com.edihasaj.klyp",
  ]
end
