cask "klyp" do
  version "0.1.11"
  sha256 "9feece5403e6929c1ea34d3950110c7416505c119c406313485315fedbf443c9"

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
