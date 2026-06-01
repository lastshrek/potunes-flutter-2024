import 'package:crypto/crypto.dart';
import 'dart:convert';

String hashPassword(String rawPassword) {
  return sha256.convert(utf8.encode(rawPassword)).toString();
}
