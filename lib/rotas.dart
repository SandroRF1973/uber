import 'package:flutter/material.dart';
import 'package:uber/telas/cadastro.dart';
import 'package:uber/telas/home.dart';
import 'package:uber/telas/painel_motorista.dart';
import 'package:uber/telas/painel_passageiro.dart';

class Rotas {
  static Route<dynamic> gerarRotas(RouteSettings settings) {
    switch (settings.name) {
      case "/":
        return MaterialPageRoute(builder: (_) => const Home());
      case "/cadastro":
        return MaterialPageRoute(builder: (_) => const Cadastro());
      case "/painel-motorista":
        return MaterialPageRoute(builder: (_) => const PainelMotorista());
      case "/painel-passageiro":
        return MaterialPageRoute(builder: (_) => const PainelPassageiro());
      default:
        return _erroRota();
    }
  }

  static Route<dynamic> _erroRota() {
    return MaterialPageRoute(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Tela não encontrada!"),
          ),
          body: const Center(
            child: Text("Tela não encontrada!"),
          ),
        );
      },
    );
  }
}