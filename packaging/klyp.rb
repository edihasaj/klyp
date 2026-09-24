cask "klyp" do
  version "0.1.20"
  sha256 "839d6bf7c0e22e719aa4e1ef5886598b8b57f13f572d08e397de8cdb42afb57d"

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
