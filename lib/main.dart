import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:uber/rotas.dart';
import 'package:uber/telas/home.dart';

final ThemeData theme = ThemeData();

final ThemeData temaPadrao = ThemeData().copyWith(
    colorScheme: theme.colorScheme.copyWith(
        primary: const Color(0xff37474f), secondary: const Color(0xff546e7a)));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(MaterialApp(
    title: "Uber",
    home: const Home(),
    theme: temaPadrao,
    initialRoute: "/",
    onGenerateRoute: Rotas.gerarRotas,
    debugShowCheckedModeBanner: false,
  ));
}
