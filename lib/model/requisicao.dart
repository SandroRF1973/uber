import 'package:uber/model/destino.dart';
import 'package:uber/model/usuario.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Requisicao {
  String? _id;
  String? _status;
  Usuario? _passageiro;
  Usuario? _motorista;
  Destino? _destino;

  Requisicao() {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference ref = db.collection("requisicoes").doc();
    id = ref.id;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> dadosPassageiro = {
      "nome": passageiro.nome,
      "email": passageiro.email,
      "tipoUsuario": passageiro.tipoUsuario,
      "idUsuario": passageiro.idUsuario,
      "latitude": passageiro.latitude,
      "longitude": passageiro.longitude,
    };

    Map<String, dynamic> dadosDestino = {
      "rua": destino.rua,
      "numero": destino.numero,
      "bairro": destino.bairro,
      "cep": destino.cep,
      "latitude": destino.latitude,
      "longitude": destino.longitude,
    };

    Map<String, dynamic> dadosRequisicao = {
      "id": id,
      "status": status,
      "passageiro": dadosPassageiro,
      "motorista": null,
      "destino": dadosDestino,
    };

    return dadosRequisicao;
  }

  Destino get destino => _destino!;

  set destino(Destino value) {
    _destino = value;
  }

  Usuario get motorista => _motorista!;

  set motorista(Usuario value) {
    _motorista = value;
  }

  Usuario get passageiro => _passageiro!;

  set passageiro(Usuario value) {
    _passageiro = value;
  }

  String get status => _status!;

  set status(String value) {
    _status = value;
  }

  String get id => _id!;

  set id(String value) {
    _id = value;
  }
}
