cask "klyp" do
  version "0.1.5"
  sha256 "e08577af9e981f5b2c88276094594e2870fd92e1ca028186df96f9a2f427a904"

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
