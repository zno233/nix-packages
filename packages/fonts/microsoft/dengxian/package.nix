# DengXian (等线) — the default Simplified Chinese UI typeface of
# Windows 10/11. It ships with zh-CN images and Office but is absent from
# en-US Windows images, so it belongs to the zh-only side of the edition
# split (`windows-fonts-zh-cn` vs `windows-fonts-en-us`).
{
  mkMicrosoftFontDerivation,
}:
mkMicrosoftFontDerivation {
  pname = "microsoft-dengxian";
  fontFamily = "DengXian";

  files = [
    "Deng.ttf"
    "Dengb.ttf"
    "Dengl.ttf"
  ];
}
