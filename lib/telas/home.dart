import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final TextEditingController? _controllerEmail = TextEditingController();
  final TextEditingController? _controllerSenha = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(image: DecorationImage(
              image: AssetImage("imagens/fundo.png"),
              fit: BoxFit.cover),
      ),
    );
  }
}
