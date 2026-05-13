cask "klyp" do
  version "0.1.10"
  sha256 "26ad9effbfde7373e033344dce9af93ed25e4b6e560fab9ba811b24fc18e7d47"

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
