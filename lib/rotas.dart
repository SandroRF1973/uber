import 'package:flutter/material.dart';
import 'package:uber/telas/cadastro.dart';
import 'package:uber/telas/corrida.dart';
import 'package:uber/telas/home.dart';
import 'package:uber/telas/painel_motorista.dart';
import 'package:uber/telas/painel_passageiro.dart';

class Rotas {
  static Route<dynamic> gerarRotas(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case "/":
        return MaterialPageRoute(builder: (_) => const Home());
      case "/cadastro":
        return MaterialPageRoute(builder: (_) => const Cadastro());
      case "/painel-motorista":
        return MaterialPageRoute(builder: (_) => const PainelMotorista());
      case "/painel-passageiro":
        return MaterialPageRoute(builder: (_) => const PainelPassageiro());
      case "/corrida":
        if (args is String) {
          return MaterialPageRoute(builder: (_) => Corrida(args));
        }
        return _erroRota();
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
