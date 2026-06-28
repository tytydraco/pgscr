import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:http/http.dart';
import 'package:path/path.dart';
import 'package:slugify/slugify.dart';

Future<void> main(List<String> arguments) async {
  final catalogFile = File('catalog.csv');
  if (!catalogFile.existsSync()) {
    final catalogFileRaw = await get(
      Uri.parse('https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv'),
    );
    await catalogFile.writeAsBytes(catalogFileRaw.bodyBytes);
  }

  final csvData = await catalogFile
      .openRead()
      .transform(utf8.decoder)
      .transform(csv.decoder)
      .toList();

  final booksDir = Directory('books/');
  await booksDir.create();
  for (final row in csvData.skip(1)) {
    final id = row[0] as String;
    final title = row[3] as String;

    stdout.writeln('$id\t$title');

    final titleSlug = slugify(title, delimiter: '_');

    for (final format in [
      'epub3.images',
      'epub.images',
      'epub.noimages',
      'txt.utf-8',
    ]) {
      final ext = format.contains('epub') ? 'epub' : 'txt';

      final bookFileName = '$titleSlug.$ext';
      final bookFile = File(join(booksDir.path, bookFileName));

      if (bookFile.existsSync()) break;

      try {
        final bookFileRaw = await get(
          Uri.parse('https://www.gutenberg.org/ebooks/$id.$format'),
        );

        if (bookFileRaw.statusCode != 200) continue;

        await bookFile.writeAsBytes(bookFileRaw.bodyBytes);
        stdout.writeln('DONWLOADED');
      } on Exception catch (_) {}
    }
  }
}
