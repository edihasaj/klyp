cask "klyp" do
  version "0.1.15"
  sha256 "03abe86d37a6a32d84ea926f16f49ef9ad88954e2896e9fe6b0438262bc0eae1"

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
