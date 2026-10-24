{
  mkMicrosoftFontDerivation,
  ...
}:
mkMicrosoftFontDerivation {
  pname = "microsoft-nirmala";
  fontFamily = "Nirmala UI";

  files = [
    "Nirmala.ttf"
    "NirmalaB.ttf"
    "NirmalaS.ttf"
  ];
}
