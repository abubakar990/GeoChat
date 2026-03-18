import 'dart:convert';
import 'package:cryptography/cryptography.dart';

void main() async {
  final hash = await Sha256().hash(utf8.encode('hello'));
  print(hash.bytes);
}
