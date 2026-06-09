cask "klyp" do
  version "0.1.14"
  sha256 "605a8976f8a9fe7f3078f7257149559ea33fce564cac229d5198b3583f875a0e"

  url "https://github.com/edihasaj/klyp/releases/download/v#{version}/Klyp.app.zip"
  name "Klyp"
  desc "Lightweight clipboard history manager for macOS"
  homepage "https://github.com/edihasaj/klyp"

  depends_on macos: ">= :sonoma"

  app "Klyp.app"

  zap trash: [
    "~/Library/Application Support/Klyp",
    "~/Library/Caches/com.edihasaj.klyp",
    "~/Library/Preferences/com.edihasaj.klyp.plist",
  ]
end
