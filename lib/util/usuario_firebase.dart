import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uber/model/usuario.dart';

class UsuarioFirebase {
  static Future<dynamic> getUsuarioAtual() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    return auth.currentUser;
  }

  static Future<Usuario> getDadosUsuarioLogado() async {
    final firebaseUser = await getUsuarioAtual();
    String idUsuario = firebaseUser.uid;

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot snapshot =
        await db.collection("usuarios").doc(idUsuario).get();

    Map<String, dynamic> dados = snapshot.data() as Map<String, dynamic>;
    String tipoUsuario = dados["tipoUsuario"];
    String email = dados["email"];
    String nome = dados["nome"];

    Usuario usuario = Usuario();
    usuario.idUsuario = idUsuario;
    usuario.tipoUsuario = tipoUsuario;
    usuario.email = email;
    usuario.nome = nome;

    return usuario;
  }

  static atualizarDadosLocalizacao(
      String idRequisicao, double lat, double lon, String tipo) async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    Usuario usuario = await getDadosUsuarioLogado();
    usuario.latitude = lat;
    usuario.longitude = lon;

    db
        .collection("requisicoes")
        .doc(idRequisicao)
        // ignore: unnecessary_string_interpolations
        .update({"$tipo": usuario.toMap()});
  }
}
