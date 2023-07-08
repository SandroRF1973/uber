import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
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
  final CameraPosition _posicaoCamera =
      const CameraPosition(target: LatLng(-23.563999, -46.653256));

  Set<Marker> _marcadores = {};
  late Map<String, dynamic> _dadosRequisicao;
  String _idRequisicao = "";
  late Position _localMotorista;
  String _statusRequisicao = StatusRequisicao.AGUARDANDO;

  //Controles para exibição na tela
  String _textoBotao = "Aceitar corrida";
  Color _corBotao = const Color(0xff1ebbd8);
  late Function _funcaoBotao;
  String _mensageStatus = "";

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
      // ignore: unnecessary_null_comparison
      if (position != null) {
        // ignore: unnecessary_null_comparison
        if (_idRequisicao != null && _idRequisicao.isNotEmpty) {
          if (_statusRequisicao != StatusRequisicao.AGUARDANDO) {
            UsuarioFirebase.atualizarDadosLocalizacao(
                _idRequisicao, position.latitude, position.longitude);
          } else {
            //aguardando
            setState(() {
              _localMotorista = position;
            });
            _statusAguardando();
          }
        }
      }
    });
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirMarcador(Position local, String icone, String infoWindow) async {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio), icone)
        .then((BitmapDescriptor bitmapDescriptor) {
      Marker marcador = Marker(
          markerId: MarkerId(icone),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: infoWindow),
          icon: bitmapDescriptor);

      setState(() {
        _marcadores.add(marcador);
      });
    });
  }

  _adicionarListenerRequisicao() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    db
        .collection("requisicoes")
        .doc(_idRequisicao)
        .snapshots()
        .listen((snapshot) {
      // ignore: unnecessary_null_comparison
      if (snapshot.data != null) {
        _dadosRequisicao = snapshot.data() as Map<String, dynamic>;
        //Map<String, dynamic> dados = snapshot.data as Map<String, dynamic>;
        Map<String, dynamic> dados = snapshot.data() as Map<String, dynamic>;
        _statusRequisicao = dados["status"];

        switch (_statusRequisicao) {
          case StatusRequisicao.AGUARDANDO:
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO:
            _statusACaminho();
            break;
          case StatusRequisicao.VIAGEM:
            _statusEmViagem();
            break;
          case StatusRequisicao.FINALIZADA:
            _statusFinalizada();
            break;
        }
      }
    });
  }

  _statusAguardando() {
    _alterarBotaoPrincipal(
        "Aceitar Corrida", const Color(0xff1ebbd8), _aceitarCorrida);

    // ignore: unnecessary_null_comparison
    if (_localMotorista != null) {
      double motoristaLat = _localMotorista.latitude;
      double motoristaLon = _localMotorista.longitude;

      Position position = Position(
          longitude: motoristaLon,
          latitude: motoristaLat,
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          timestamp: null);

      _exibirMarcador(position, "imagens/motorista.png", "Motorista");
      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);

      _movimentarCamera(cameraPosition);
    }
  }

  _statusACaminho() {
    _mensageStatus = "A caminho do passageiro";
    _alterarBotaoPrincipal(
        "Iniciar corrida", const Color(0xff1ebbd8), _iniciarCorrida);

    double latitudePassageiro = _dadosRequisicao["passageiro"]["latitude"];
    double longitudePassageiro = _dadosRequisicao["passageiro"]["longitude"];

    double latitudeMotorista = _dadosRequisicao["motorista"]["latitude"];
    double longitudeMotorista = _dadosRequisicao["motorista"]["longitude"];

    //Exibir dois marcadores
    _exibirDoisMarcadores(LatLng(latitudeMotorista, longitudeMotorista),
        LatLng(latitudePassageiro, longitudePassageiro));

    double nLat, nLon, sLat, sLon;

    if (latitudeMotorista <= latitudePassageiro) {
      sLat = latitudeMotorista;
      nLat = latitudePassageiro;
    } else {
      sLat = latitudePassageiro;
      nLat = latitudeMotorista;
    }

    if (longitudeMotorista <= longitudePassageiro) {
      sLon = longitudeMotorista;
      nLon = longitudePassageiro;
    } else {
      sLon = longitudePassageiro;
      nLon = longitudeMotorista;
    }

    _movimentarCameraBounds(LatLngBounds(
        northeast: LatLng(nLat, nLon), southwest: LatLng(sLat, sLon)));
  }

  _finalizarCorrida() {
    FirebaseFirestore db = FirebaseFirestore.instance;
    db
        .collection("requisicoes")
        .doc(_idRequisicao)
        .update({"status": StatusRequisicao.FINALIZADA});

    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db
        .collection("requisicao_ativa")
        .doc(idPassageiro)
        .update({"status": StatusRequisicao.FINALIZADA});

    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db
        .collection("requisicao_ativa_motorista")
        .doc(idMotorista)
        .update({"status": StatusRequisicao.FINALIZADA});
  }

  _statusFinalizada() {
    //Calcula o valor da corrida
    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];

    double latitudeOrigem = _dadosRequisicao["origem"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["origem"]["longitude"];

    double distanciaEmMetros = Geolocator.distanceBetween(
        latitudeOrigem, longitudeOrigem, latitudeDestino, longitudeDestino);

    //Converte para KM
    double distanciaKM = distanciaEmMetros / 1000;

    //8 é o valor cobrado por KM
    double valorViagem = distanciaKM * 8;

    //Formatar valor viagem
    var f = NumberFormat("#,##0.0", "pt_BR");
    var valorViagemFormatado = f.format(valorViagem);

    _mensageStatus = "Viagem finalizada";
    _alterarBotaoPrincipal("Confirmar - R\$ $valorViagemFormatado",
        const Color(0xff1ebbd8), _confirmarCorrida);
  }

  _confirmarCorrida() {}

  _statusEmViagem() {
    _mensageStatus = "Em viagem";
    _alterarBotaoPrincipal(
        "Finalizar corrida", const Color(0xff1ebbd8), _finalizarCorrida);

    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];

    double latitudeOrigem = _dadosRequisicao["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["motorista"]["longitude"];

    //Exibir dois marcadores
    _exibirDoisMarcadores(LatLng(latitudeOrigem, longitudeOrigem),
        LatLng(latitudeDestino, longitudeDestino));

    double nLat, nLon, sLat, sLon;

    if (latitudeOrigem <= latitudeDestino) {
      sLat = latitudeOrigem;
      nLat = latitudeDestino;
    } else {
      sLat = latitudeDestino;
      nLat = latitudeOrigem;
    }

    if (longitudeOrigem <= longitudeDestino) {
      sLon = longitudeOrigem;
      nLon = longitudeDestino;
    } else {
      sLon = longitudeDestino;
      nLon = longitudeOrigem;
    }

    _movimentarCameraBounds(LatLngBounds(
        northeast: LatLng(nLat, nLon), southwest: LatLng(sLat, sLon)));
  }

  _iniciarCorrida() {
    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection("requisicoes").doc(_idRequisicao).update({
      "origem": {
        "latitude": _dadosRequisicao["motorista"]["latitude"],
        "longitude": _dadosRequisicao["motorista"]["longitude"]
      },
      "status": StatusRequisicao.VIAGEM
    });

    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db
        .collection("requisicao_ativa")
        .doc(idPassageiro)
        .update({"status": StatusRequisicao.VIAGEM});

    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db
        .collection("requisicao_ativa_motorista")
        .doc(idMotorista)
        .update({"status": StatusRequisicao.VIAGEM});
  }

  _movimentarCameraBounds(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newLatLngBounds(latLngBounds, 100));
  }

  _exibirDoisMarcadores(LatLng latLngMotorista, LatLng latLngPassageiro) {
    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    Set<Marker> listaMarcadores = {};
    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "imagens/motorista.png")
        .then((BitmapDescriptor icone) {
      Marker marcador1 = Marker(
          markerId: const MarkerId("marcador-motorista"),
          position: LatLng(latLngMotorista.latitude, latLngMotorista.longitude),
          infoWindow: const InfoWindow(title: "local motorista"),
          icon: icone);
      listaMarcadores.add(marcador1);
      // ignore: avoid_print
      print(
          '==========Latitude Motorista: ${latLngMotorista.latitude} Longitude Motorista:  ${latLngMotorista.longitude}');
    });

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: pixelRatio),
            "imagens/passageiro.png")
        .then((BitmapDescriptor icone) {
      Marker marcador2 = Marker(
          markerId: const MarkerId("marcador-passageiro"),
          position:
              LatLng(latLngPassageiro.latitude, latLngPassageiro.longitude),
          infoWindow: const InfoWindow(title: "local passageiro"),
          icon: icone);
      listaMarcadores.add(marcador2);
      // ignore: avoid_print
      print(
          '==========Latitude Passageiro: ${latLngPassageiro.latitude} Longitude Passageiro:  ${latLngPassageiro.longitude}');
    });

    setState(() {
      _marcadores = listaMarcadores;
    });
  }

  _aceitarCorrida() async {
    Usuario motorista = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista.latitude = _localMotorista.latitude;
    motorista.longitude = _localMotorista.longitude;

    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao["id"];

    db.collection("requisicoes").doc(idRequisicao).update({
      "motorista": motorista.toMap(),
      "status": StatusRequisicao.A_CAMINHO,
    }).then((_) {
      //atualiza requisição ativa
      String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
      db.collection("requisicao_ativa").doc(idPassageiro).update({
        "status": StatusRequisicao.A_CAMINHO,
      });

      //salvar requisição ativa para motorista
      String idMotorista = motorista.idUsuario;
      db.collection("requisicao_ativa_motorista").doc(idMotorista).set({
        "id_requisicao": idRequisicao,
        "idUsuario": idMotorista,
        "status": StatusRequisicao.A_CAMINHO,
      });
    });
  }

  @override
  void initState() {
    super.initState();

    _idRequisicao = widget.idRequisicao;

    //adicionar listener para mudanças na requisição
    _adicionarListenerRequisicao();

    //_recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel corrida - $_mensageStatus"),
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
