cask "klyp" do
  version "0.1.21"
  sha256 "e6e696a26e7e67796dc61e2f58d881a529fea7d3b5dc2086518ef0f0d48ea8c4"

  url "https://github.com/edihasaj/klyp/releases/download/v#{version}/Klyp.app.zip"
  name "Klyp"
  desc "Lightweight clipboard history manager"
  homepage "https://github.com/edihasaj/klyp"

  depends_on macos: :sonoma

  app "Klyp.app"

  zap trash: [
    "~/Library/Application Support/Klyp",
    "~/Library/Caches/com.edihasaj.klyp",
    "~/Library/Preferences/com.edihasaj.klyp.plist",
  ]
end
