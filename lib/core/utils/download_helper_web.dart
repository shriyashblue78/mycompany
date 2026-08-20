import 'dart:html' as html;

Future<void> downloadFile(String url, String filename) async {
  html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..setAttribute("target", "_blank")
    ..click();
}
