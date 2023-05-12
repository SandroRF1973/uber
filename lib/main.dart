import 'package:flutter/material.dart';
import 'package:uber/telas/home.dart';

final ThemeData theme = ThemeData();

final ThemeData temaPadrao = ThemeData().copyWith(
    colorScheme: theme.colorScheme.copyWith(
        primary: const Color(0xff37474f), secondary: const Color(0xff546e7a)));

void main() {
  runApp(MaterialApp(
    title: "Uber",
    home: const Home(),
    theme: temaPadrao,
    debugShowCheckedModeBanner: false,
  ));
}
