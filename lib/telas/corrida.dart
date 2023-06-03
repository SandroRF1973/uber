import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uber/model/usuario.dart';
import 'package:uber/util/status_requisicao.dart';
import 'package:uber/util/usuario_firebase.dart';

class Corrida extends StatefulWidget {
  final String idRequisicao;
  const Corrida(this.idRequisicao, {super.key});

  @override
  State<Corrida> createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {
  final Completer<GoogleMapController> _controller = Completer();
  CameraPosition _posicaoCamera =
      const CameraPosition(target: LatLng(-23.563999, -46.653256));

  final Set<Marker> _marcadores = {};
  late Map<String, dynamic> _dadosRequisicao;
  late Position _localMotorista;

  //Controles para exibição na tela
  String _textoBotao = "Aceitar corrida";
  Color _corBotao = const Color(0xff1ebbd8);
  late Function _funcaoBotao;

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _adicionarListenerLocalizacao() {
    var locationOptions = const LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: 10);

    Geolocator.getPositionStream(locationSettings: locationOptions)
        .listen((Position position) {
      _exibirMarcadorPassageiro(position);
      _posicaoCamera = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);

      _movimentarCamera(_posicaoCamera);

      setState(() {
        _localMotorista = position;
      });
    });
  }

  _recuperarUltimaLocalizacaoConhecida() async {
    Position? position = await Geolocator.getLastKnownPosition();

    setState(() {
      if (position != null) {
        _exibirMarcadorPassageiro(position);

        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude), zoom: 19);

        _movimentarCamera(_posicaoCamera);
        _localMotorista = position;
      }
    });
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirMarcadorPassageiro(Position local) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "imagens/motorista.png")
        .then((BitmapDescriptor icone) {
      Marker marcadorMotorista = Marker(
          markerId: const MarkerId("marcador-motorista"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: const InfoWindow(title: "Meu local"),
          icon: icone);

      setState(() {
        _marcadores.add(marcadorMotorista);
      });
    });
  }

  _recuperarRequisicao() async {
    String idRequisicao = widget.idRequisicao;

    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot documentSnapshot =
        await db.collection("requisicoes").doc(idRequisicao).get();

    //_dadosRequisicao = documentSnapshot.data as Map<String, dynamic>;
    if (documentSnapshot.exists) {
      _dadosRequisicao = documentSnapshot.data() as Map<String, dynamic>;
      _adicionarListenerRequisicao();
    } else {
      // Handle the case when the document doesn't exist
    }
  }

  _adicionarListenerRequisicao() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao["id"];
    await db
        .collection("requisicoes")
        .doc(idRequisicao)
        .snapshots()
        .listen((snapshot) {
      // ignore: unnecessary_null_comparison
      if (snapshot.data != null) {
        //Map<String, dynamic> dados = snapshot.data as Map<String, dynamic>;
        Map<String, dynamic> dados = snapshot.data() as Map<String, dynamic>;
        String status = dados["status"];

        switch (status) {
          case StatusRequisicao.AGUARDANDO:
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO:
            break;
          case StatusRequisicao.VIAGEM:
            break;
          case StatusRequisicao.FINALIZADA:
            break;
        }
      }
    });
  }

  _statusAguardando() {
    _alterarBotaoPrincipal(
        "Aceitar Corrida", const Color(0xff1ebbd8), _aceitarCorrida);
  }

  _aceitarCorrida() async {
    Usuario motorista = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista.latitude = _localMotorista.latitude;
    motorista.longitude = _localMotorista.longitude;

    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao["id"];

    db.collection("requisicoes").doc(idRequisicao).update({
      "motorista": "",
      "status": StatusRequisicao.A_CAMINHO,
    });
  }

  @override
  void initState() {
    super.initState();
    _recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();

    _recuperarRequisicao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel corrida"),
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _posicaoCamera,
            onMapCreated: _onMapCreated,
            // myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _marcadores,
          ),
          Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: Platform.isIOS
                    ? const EdgeInsets.fromLTRB(20, 10, 20, 25)
                    : const EdgeInsets.all(10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _corBotao,
                      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16)),
                  onPressed: () {
                    _funcaoBotao();
                  },
                  child: Text(
                    _textoBotao,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ))
        ],
      ),
    );
  }
}
