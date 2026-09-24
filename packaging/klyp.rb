cask "klyp" do
  version "0.1.17"
  sha256 "391f2b0978b48d7963e88558fa09e35b45cc9ab3d065e5cc33ed5a92b9f5ef4e"

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
