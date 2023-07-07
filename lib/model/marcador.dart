// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Marcador {
  LatLng? local;
  String? caminhoImagem;
  String? titulo;

  //Construtor
  Marcador(
    this.local,
    this.caminhoImagem,
    this.titulo,
  );
}
