# Windows edition splits shared by the two registration paths:
# the microsoft scope (overlays/fonts/scopes.nix) and the top-level
# aggregates (overlays/fonts/aggregates.nix).
#
# Everything here is a static list of package names (strings), so this
# manifest evaluates without any scope bound — the consumers resolve each
# name against their own scope object, which also fails loudly if a name
# ever drifts out of the tree.
{
  # Fonts NOT shipped by an en-US Windows 10/11 image. A stock en-US image
  # carries the full CJK UI set (YaHei, SimSun, JhengHei, MingLiU-ExtB,
  # Malgun, MS/Yu Gothic) for font fallback, but not the zh-CN-only SimHei,
  # KaiTi, and FangSong (Windows 7-era legacy fonts) nor DengXian.
  enUsExcluded = [
    "dengxian"
    "fangsong"
    "kaiti"
    "simhei"
  ];

  # Minimal sets that keep Word documents intact: the Office core/theme
  # families, the classic Windows document faces, Segoe UI's UI/emoji
  # variants, and the usual decorative/Office-bundled fonts. Exotic-script
  # faces (Tibetan, Mongolian, Yi, Tai, PhagsPa, Myanmar, Javanese, Indian
  # scripts, Cherokee, Thaana, N'Ko, Thai, ...) are left to the full
  # aggregates.
  slimCore = [
    "arial"
    "bahnschrift"
    "calibri"
    "cambria"
    "cambria-math"
    "candara"
    "comic-sans-ms"
    "consolas"
    "constantia"
    "corbel"
    "courier-new"
    "franklin-gothic-medium"
    "gabriola"
    "georgia"
    "impact"
    "ink-free"
    "lucida-console"
    "lucida-sans-unicode"
    "marlett"
    "microsoft-sans-serif"
    "palatino-linotype"
    "segoe-icons"
    "segoe-print"
    "segoe-script"
    "segoe-ui"
    "segoe-ui-symbols"
    "segoe-ui-variable"
    "sitka"
    "sylfaen"
    "symbol"
    "tahoma"
    "times-new-roman"
    "trebuchet-ms"
    "verdana"
    "webdings"
    "wingdings"
  ];

  # The zh-CN slim add-on carries only the Simplified Chinese families a
  # Chinese Office install has (宋体/黑体/楷体/仿宋/微软雅黑/等线); the
  # Traditional Chinese, Japanese, and Korean faces are deliberately left
  # to the full aggregates because they are the largest files in the tree
  # (~174 MiB for JhengHei/MingLiU/MS Gothic/Yu Gothic/Malgun) and a zh-CN
  # Word document does not need them.
  slimZhCn = [
    "dengxian"
    "fangsong"
    "kaiti"
    "microsoft-yahei"
    "simhei"
    "simsun"
  ];
}
